#!/bin/bash

# 슬랙 웹훅 URL 설정
SLACK_WEBHOOK_URL="..."

# 현재 날짜와 시간 가져오기
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# 모든 도커 이미지 목록 가져오기
IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}")

# jq가 설치되어 있는지 확인
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please install jq to continue."
    exit 1
fi

# 각 이미지에 대해 Trivy 검사 수행
for IMAGE in $IMAGES; do
    # Trivy로 이미지 검사
    RESULT=$(trivy image --scanners vuln --format json $IMAGE)

    # critical 취약점만 필터링
    CRITICAL_VULNERABILITIES=$(echo "$RESULT" | jq '[.Results[] | select(.Vulnerabilities[]? | .Severity == "CRITICAL")]')

    # 파일명 설정 (날짜와 시간 포함)
    FILENAME="critical_vulnerabilities_${IMAGE//:/_}_${TIMESTAMP}.txt"

    if [ $(echo "$CRITICAL_VULNERABILITIES" | jq 'length') -gt 0 ]; then
        # 이미지 이름과 취약점 개수 저장
        echo "치명적인 보안 취약점이  *$IMAGE* 이미지 에서 발견되었습니다!" > "$FILENAME"
        echo "$CRITICAL_VULNERABILITIES" | jq '.[] | .Vulnerabilities[] | {PkgName: .PkgName, InstalledVersion: .InstalledVersion, FixedVersion: .FixedVersion, Severity: .Severity, Title: .Title}' >> "$FILENAME"

        # 슬랙 메시지 포맷
        MESSAGE="치명적인 보안 취약점이 *$IMAGE* 이미지 에서 발견되었습니다!  \`$FILENAME\` 파일을 확인해주세요!!"

        # 슬랙으로 메시지 전송
        curl -X POST --data-urlencode "payload={\"text\": \"$MESSAGE\"}" $SLACK_WEBHOOK_URL
    else
        echo "$IMAGE 는 안전합니다!"
        # 빈 파일 생성 (선택적)
        echo "$IMAGE 는 안전합니다!" > "$FILENAME"
    fi
done
