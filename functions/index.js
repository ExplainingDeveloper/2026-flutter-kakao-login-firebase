const { onCall, HttpsError } = require('firebase-functions/https');
const { defineString } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

const kakaoAppId = defineString('KAKAO_APP_ID');

exports.kakaoLogin = onCall(async (request) => {
  const accessToken = request.data?.accessToken;
  if (typeof accessToken !== 'string' || accessToken.length === 0) {
    throw new HttpsError('invalid-argument', '카카오 액세스 토큰이 필요해요.');
  }

  const tokenInfo = await kakaoGet('/v1/user/access_token_info', accessToken);
  if (String(tokenInfo.app_id) !== kakaoAppId.value()) {
    throw new HttpsError(
      'permission-denied',
      '다른 앱에서 발급된 카카오 토큰이에요.',
    );
  }

  const me = await kakaoGet('/v2/user/me', accessToken);
  const profile = me.kakao_account?.profile ?? {};
  const uid = `kakao:${tokenInfo.id}`;
  const userProps = {};
  if (profile.nickname) userProps.displayName = profile.nickname;
  if (profile.profile_image_url) {
    userProps.photoURL = profile.profile_image_url.replace(/^http:/, 'https:');
  }
  await upsertUser(uid, userProps);

  const customToken = await getAuth().createCustomToken(uid);
  return { customToken };
});

exports.deleteAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', '로그인이 필요해요.');
  }
  await getAuth().deleteUser(request.auth.uid);
  return { deleted: true };
});

async function kakaoGet(path, accessToken) {
  const response = await fetch(`https://kapi.kakao.com${path}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (response.status === 401) {
    throw new HttpsError('unauthenticated', '카카오 토큰이 유효하지 않아요.');
  }
  if (!response.ok) {
    throw new HttpsError('unavailable', `카카오 API 오류 (${response.status})`);
  }
  return response.json();
}

async function upsertUser(uid, props) {
  try {
    await getAuth().updateUser(uid, props);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    await getAuth().createUser({ uid, ...props });
  }
}
