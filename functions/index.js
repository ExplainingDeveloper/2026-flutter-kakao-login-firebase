const {onCall, HttpsError} = require("firebase-functions/https");
const {defineString} = require("firebase-functions/params");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");

initializeApp();

// 카카오 디벨로퍼스의 앱 ID (functions/.env 의 KAKAO_APP_ID)
const kakaoAppId = defineString("KAKAO_APP_ID");

/**
 * 카카오 액세스 토큰을 확인하고 Firebase 커스텀 토큰을 발급한다.
 * 앱은 이 토큰으로 signInWithCustomToken()을 호출한다.
 */
exports.kakaoLogin = onCall(async (request) => {
  const accessToken = request.data?.accessToken;
  if (typeof accessToken !== "string" || accessToken.length === 0) {
    throw new HttpsError("invalid-argument", "카카오 액세스 토큰이 필요해요.");
  }

  // 1. 카카오 서버에 토큰 확인: 유효한 토큰인지, 우리 앱에서 발급된 토큰인지
  const tokenInfo = await kakaoGet("/v1/user/access_token_info", accessToken);
  if (String(tokenInfo.app_id) !== kakaoAppId.value()) {
    throw new HttpsError("permission-denied", "다른 앱에서 발급된 카카오 토큰이에요.");
  }

  // 2. 프로필 가져오기 (동의항목에 따라 비어 있을 수 있음)
  const me = await kakaoGet("/v2/user/me", accessToken);
  const profile = me.kakao_account?.profile ?? {};

  // 3. Firebase 사용자 만들기 또는 갱신. uid는 카카오 회원번호로 정한다.
  const uid = `kakao:${tokenInfo.id}`;
  const userProps = {};
  if (profile.nickname) userProps.displayName = profile.nickname;
  if (profile.profile_image_url) {
    userProps.photoURL = profile.profile_image_url.replace(/^http:/, "https:");
  }
  await upsertUser(uid, userProps);

  // 4. 커스텀 토큰 발급
  const customToken = await getAuth().createCustomToken(uid);
  return {customToken};
});

/**
 * 로그인한 사용자의 Firebase 계정을 삭제한다. (회원 탈퇴)
 */
exports.deleteAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요해요.");
  }
  await getAuth().deleteUser(request.auth.uid);
  return {deleted: true};
});

/** 카카오 API를 사용자 액세스 토큰으로 호출한다. */
async function kakaoGet(path, accessToken) {
  const response = await fetch(`https://kapi.kakao.com${path}`, {
    headers: {Authorization: `Bearer ${accessToken}`},
  });
  if (response.status === 401) {
    throw new HttpsError("unauthenticated", "카카오 토큰이 유효하지 않아요.");
  }
  if (!response.ok) {
    throw new HttpsError("unavailable", `카카오 API 오류 (${response.status})`);
  }
  return response.json();
}

/** 사용자가 있으면 정보를 갱신하고, 없으면 새로 만든다. */
async function upsertUser(uid, props) {
  try {
    await getAuth().updateUser(uid, props);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await getAuth().createUser({uid, ...props});
  }
}
