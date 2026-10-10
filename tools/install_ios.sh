#!/bin/bash
# 아이폰에 SquadLink 앱 설치 (라이트닝→USB-C 케이블 연결 + 아이폰 잠금해제 + "신뢰" 후 실행)
# 무료 개인팀(LTF44HD932)으로 개발서명 → App Store 약관(PLA) 불필요, 7일 유효.
# 사용법: tools/install_ios.sh [DEVELOPMENT_TEAM]
set -e
cd "$(dirname "$0")/.."
TEAM="${1:-LTF44HD932}"               # 막히면 H2XY4QWQLX(유료)로 재시도
APPROJ="ios/SquadLink/SquadLink.xcodeproj"
DD="/tmp/sl_dd"

echo "== 아이폰 찾는 중 =="
xcrun devicectl list devices --json-output /tmp/sl_devs.json >/dev/null 2>&1 || true
UDID=$(python3 -c "
import json,sys
try: d=json.load(open('/tmp/sl_devs.json'))
except: sys.exit()
for dev in d.get('result',{}).get('devices',[]):
    props=dev.get('deviceProperties',{})
    conn=dev.get('connectionProperties',{})
    name=props.get('name','')
    # 연결 가능한 iOS 기기
    if 'iPhone' in name or 'iPad' in name or dev.get('hardwareProperties',{}).get('platform','')=='iOS':
        print(dev.get('identifier','')); break
")
if [ -z "$UDID" ]; then
  echo "아이폰이 안 보입니다. 확인: 데이터 케이블인지 / 잠금해제 / '이 컴퓨터를 신뢰' 눌렀는지"
  exit 1
fi
echo "기기 identifier = $UDID"

echo "== 빌드(팀 $TEAM) =="
xcodebuild -project "$APPROJ" -scheme SquadLink -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DD" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic build \
  2>&1 | grep -iE "error:|BUILD SUCCEEDED|BUILD FAILED|PLA|provisioning|signing" | tail -8

APP=$(find "$DD/Build/Products" -maxdepth 3 -name "SquadLink.app" 2>/dev/null | head -1)
if [ -z "$APP" ]; then echo "빌드 산출물(.app) 없음 — 위 에러 확인"; exit 1; fi

echo "== 설치: $APP =="
xcrun devicectl device install app --device "$UDID" "$APP"
echo ""
echo "완료! 아이폰에서 처음 실행 시: 설정 > 일반 > VPN 및 기기 관리 > 개발자 앱 > 신뢰"
echo "그 다음 앱 열고 '단말 연결' → SQUAD-E1/E2 선택 → 메시지."
