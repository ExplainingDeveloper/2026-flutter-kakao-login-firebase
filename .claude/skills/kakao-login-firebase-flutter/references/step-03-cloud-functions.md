# 3단계: Cloud Functions – 카카오 토큰 확인 → Firebase 커스텀 토큰 발급

## 목적

서버 함수 두 개를 만들어 Firebase에 배포한다.

| 함수 | 하는 일 |
|---|---|
| `kakaoLogin` | 앱이 보낸 카카오 액세스 토큰을 카카오 서버에 확인한다. 우리 앱에서 발급된 토큰이 맞으면 Firebase 사용자를 만들거나 갱신하고, 커스텀 토큰을 돌려준다. |
| `deleteAccount` | 로그인한 사용자의 Firebase 계정을 삭제한다. 7단계 회원 탈퇴에서 쓴다. |

커스텀 토큰은 서버에서만 만든다. 만들려면 서비스 계정의 서명 권한이 필요하고, 그 권한을 앱에 넣으면 누구나 아무 사용자로 로그인할 수 있게 되기 때문이다.

## 필요한 정보

- `PROJECT_ID`: Firebase 프로젝트 ID
- `KAKAO_APP_ID`: 카카오 앱 ID (숫자)

## 사전 확인

1. **Blaze 요금제**: Cloud Functions는 Blaze 요금제에서만 배포된다. 0단계 F-2를 했는지 사용자에게 확인한다.
2. **Node.js 22 이상**: `node -v`로 확인한다.
   - `firebase-admin` 최신판은 Node 22 이상을 요구한다. 배포할 때 Firebase CLI가 함수 코드를 이 컴퓨터의 Node로 읽어 들이는데, Node 20에서는 `ERR_REQUIRE_ESM` 에러가 나서 배포가 실패한다.
   - 22보다 낮으면 멈추고 Node 22 설치를 안내한다. nvm을 쓰면 `nvm install 22 && nvm use 22`, 아니면 https://nodejs.org 의 LTS.
3. **Firebase 로그인**: `firebase projects:list`에 `PROJECT_ID`가 보여야 한다. 안 되면 사용자에게 `firebase login`을 부탁한다.

## A. 파일 만들기

프로젝트 루트 기준이다. 이미 있는 파일은 읽고 필요한 부분만 고친다.

### A-1. `.firebaserc` (어느 Firebase 프로젝트에 배포할지)

없으면 만든다. 있으면 `projects.default`만 확인하고, 다르면 사용자에게 물은 뒤 바꾼다.

```json
{
  "projects": {
    "default": "<PROJECT_ID>"
  }
}
```

### A-2. `firebase.json`에 functions 설정 추가

2단계 `flutterfire configure`가 이미 만든 `firebase.json`이 있을 수 있다. 그 안의 다른 키(`flutter` 등)는 그대로 두고 `functions` 키만 추가한다. 이미 `functions`가 있으면 `source`가 `functions`인지만 확인한다.

```json
{
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "ignore": ["node_modules", ".git", "firebase-debug.log", "firebase-debug.*.log", "*.local"]
    }
  ]
}
```

### A-3. `functions/package.json`

```json
{
  "name": "functions",
  "private": true,
  "main": "index.js",
  "engines": { "node": "22" }
}
```

만든 뒤 `functions/` 폴더에서 패키지를 설치한다. 버전은 npm이 최신으로 고르게 하고 직접 적지 않는다.

```bash
cd functions && npm install firebase-functions firebase-admin
```

`engines.node`가 배포될 서버의 Node 버전이다. Cloud Functions가 지원하는 버전은 Node 20, 22다 (https://firebase.google.com/docs/functions/manage-functions).

### A-4. `functions/.env` (카카오 앱 ID)

```
KAKAO_APP_ID=<KAKAO_APP_ID>
```

함수가 `defineString("KAKAO_APP_ID")`로 이 값을 읽는다. 배포할 때 CLI가 이 파일을 함께 올린다.

### A-5. `functions/index.js`

없으면 아래 내용으로 만든다. 이미 있으면(다른 함수가 있는 경우) 기존 함수는 그대로 두고 `kakaoLogin`, `deleteAccount`와 필요한 import만 추가한다.

```js
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
```

이렇게 짠 이유:
- **`app_id` 비교가 핵심 보안 장치다.** 카카오 회원번호는 앱마다 따로 붙는다. 이 비교가 없으면 다른 카카오 앱에서 받은 토큰으로도 로그인이 되고, 그 회원번호가 우리 앱의 다른 사람 회원번호와 겹치면 남의 계정으로 들어올 수 있다. `access_token_info` 응답의 `app_id`는 "토큰이 발급된 앱 ID"다 (https://developers.kakao.com/docs/ko/kakaologin/rest-api).
- **uid를 `kakao:<회원번호>`로 정한다.** 같은 카카오 사용자는 항상 같은 Firebase 사용자가 된다. 나중에 다른 로그인 방법을 붙여도 접두어로 구분된다.
- **프로필은 선택이다.** 동의항목을 안 켰거나 사용자가 동의하지 않으면 비어 있다. 그래도 로그인은 된다.
- **프로필 사진 주소를 https로 바꾼다.** 카카오가 http 주소를 주는 경우가 있다.
- 리전은 기본값(`us-central1`)을 쓴다. 다른 리전을 쓰면 앱에서도 같은 리전을 지정해야 해서 설정이 늘어난다.

## B. 배포

프로젝트 루트에서 실행한다.

```bash
firebase deploy --only functions
```

- 처음 배포는 필요한 Google Cloud API를 켜느라 몇 분 걸린다.
- 에이전트 환경에서 CLI가 입력을 기다리며 멈추거나 "non-interactive" 관련 에러로 끝나면, 사용자에게 같은 명령을 터미널에서 직접 실행해 달라고 한다. 처음 배포 때 정리 정책 같은 질문이 나올 수 있다.
- 에러 대처
  - Blaze 요금제가 필요하다는 에러: 0단계 F-2를 안내한다.
  - `ERR_REQUIRE_ESM`: Node가 22보다 낮다. "사전 확인" 2번.
  - `KAKAO_APP_ID` 값을 묻는다: `functions/.env`가 없거나 위치가 틀렸다. A-4를 확인한다.
- 성공하면 출력에 `kakaoLogin`, `deleteAccount`가 보인다.

## C. 커스텀 토큰 서명 권한 주기 (사용자가 콘솔에서)

배포된 함수가 `createCustomToken`을 쓰려면 함수를 실행하는 서비스 계정에 `iam.serviceAccounts.signBlob` 권한이 있어야 한다. 이 권한이 없으면 첫 로그인 때 아래 에러가 난다.

```
Permission iam.serviceAccounts.signBlob is required to perform this operation
```

배포 직후 미리 권한을 준다. 한 단계씩 안내하고 `완료했어요`를 기다린다 (0단계 "단계별 안내 방식"과 같음).

1. Google Cloud 콘솔 IAM 페이지를 연다.
   ```
   https://console.cloud.google.com/iam-admin/iam?project=<PROJECT_ID>
   ```
2. 목록에서 **Compute Engine 기본 서비스 계정**(`<숫자>-compute@developer.gserviceaccount.com`)을 찾는다. 2세대 Cloud Functions는 이 계정으로 실행된다.
3. 그 줄의 연필(수정) 아이콘 → **[다른 역할 추가]** → **서비스 계정 토큰 생성자** (Service Account Token Creator) → **[저장]**

권한을 주고 바로 시험하면 몇 분 동안 같은 에러가 날 수 있다. 잠시 기다렸다가 다시 시도하라고 안내한다.

`Identity and Access Management (IAM) API has not been used in project` 에러가 나면, 에러 메시지 안의 링크를 열어 **[사용]**을 누르면 된다. 켠 직후에는 몇 분 기다려야 할 수 있다.

근거: https://firebase.google.com/docs/auth/admin/create-custom-tokens (문제 해결 항목)

## 검증

- `firebase deploy` 출력에 두 함수가 성공으로 나오는지 확인한다.
- `firebase functions:list`로 `kakaoLogin`, `deleteAccount`가 보이는지 확인한다.
- 실제 로그인 테스트는 4단계가 끝난 뒤 기기에서 한다. 실패하면 `firebase functions:log`로 서버 에러를 본다.

## 완료 보고에 포함할 내용

- 만든 파일: `.firebaserc`, `firebase.json`(functions 추가), `functions/package.json`, `functions/.env`, `functions/index.js`
- 배포 결과 (함수 이름, 리전)
- 서비스 계정 권한(C)을 줬는지. 안 했으면 남은 일로 적는다.
- 흐름 한 줄: "앱 → kakaoLogin(카카오 토큰 확인 + 우리 앱 토큰인지 확인) → 커스텀 토큰 → 앱이 Firebase 로그인"
- `functions/.env`, `.firebaserc`가 `.gitignore`에 있는지 한 줄 안내
