# Trivy-Image-Scan-Examples
Trivy를 사용한 컨테이너 이미지의 정적 분석


## 이미지 스캔의 필요성
컨테이너 보안은 기술 산업이 점점 더 빠른 속도로 컨테이너로 이동함에 따라 요즘 사이버 보안의 중요한 측면 중 하나가 되고 있다.
- 컨테이너 이미지는 기본 이미지에서 파생되고, 기본 이미지 내에는 취약할 수 있는 많은 요소가 있다.
- 따라서 개발자가 통제할 수 없는 부분이 많기 때문에 이미지를 스캔해야 할 필요성이 생긴다.

## Trivy
Aquasecurity Trivy는 이 모든 것을 도와주는 도구이다.
컨테이너 이미지, 파일 시스템 및 Git저장소를 스캔하여 Iac, Kubernetes 매니패스트 및 Dockerfile내의 취약점과 잘못된 구성을 찾아낼 수 있다.
많은 컨테이너 취약점 스캐너가 있지만 Trivy를 사용해 보갰다.
trivy만 설치하면 바로 시작할 수 있다.

## 실습
Trivy 스캔 결과를 Slack으로 자동 알림

### 0. Trivy 다운로드

```
# 외부 패키지를 설치 하기 위해 필요한 도구 설치
sudo apt-get install wget apt-transport-https gnupg lsb-release

# 공식 GPG키 가져오기
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/trivy-archive-keyring.gpg

# Trivy 저장소 추가
echo "deb [signed-by=/usr/share/keyrings/trivy-archive-keyring.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list

# 패키지 목록 업데이트
sudo apt-get update

# Trivy 설치
sudo apt-get install trivy
```

### 1. 환경 준비
- **Slack Webhook을 설정해야 한다.**

- **Slack에서 원하는 채널로 이동한다.**
    앱 추가하기에서 Incoming Webhooks를 검색하여 설치한다.
    ![image](https://github.com/user-attachments/assets/bc48e369-f499-4a32-95e8-48fe58f2eb69)

- **Webhook URL을 생성하고 저장한다.**
    ![image](https://github.com/user-attachments/assets/125ce9c1-4a33-42e8-97df-97164d9ad27f)
    채널 추가 후 앱 생성
    ![image](https://github.com/user-attachments/assets/14e9360a-44ec-47fa-857b-8d328c84f97f)
    
    이후 수신 웹후크 통합 앱 추가를 누르면 URL이 생성된다.

### 2. Dockerfile 및 Node.js 애플리케이션 작성

- **jq 설치**
  - JSON 데이터 파싱: Trivy가 도커 이미지를 검사한 결과를 JSON 형식으로 출력한다. jq는 이 JSON 데이터를 쉽게 필터링하고 변환할 수 있는 강력한 도구입니다.
  - 취약점 필터링: 스크립트에서는 Trivy의 검사 결과에서 "CRITICAL" 심각도를 가진 취약점만 추출할 때 사용한다.
    
```
sudo apt-get install -y jq
```

- **존재하는 Docker image들**
  <br>
![image](https://github.com/user-attachments/assets/7bb946fc-a51d-4683-a65e-4ffee4987593)



- **Trivy를 실행하고, 결과를 Slack으로 전송한다.**
- **trivy_scan.sh 파일**
```
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
        echo "치명적인 보안 취약점이  $IMAGE 이미지 에서 발견되었습니다!" > "$FILENAME"
        echo "$CRITICAL_VULNERABILITIES" | jq '.[] | .Vulnerabilities[] | {PkgName: .PkgName, InstalledVersion: .InstalledVersion, FixedVersion: .FixedVersion, Severity: .Severity, Title: .Title}' >> "$FILENAME"

        # 슬랙 메시지 포맷
        MESSAGE="치명적인 보안 취약점이 *$IMAGE*이미지 에서 발견되었습니다!  \`$FILENAME\` 파일을 확인해주세요!!"

        # 슬랙으로 메시지 전송
        curl -X POST --data-urlencode "payload={\"text\": \"$MESSAGE\"}" $SLACK_WEBHOOK_URL
    else
        echo "$IMAGE 는 안전합니다!"
        # 빈 파일 생성 (선택적)
        echo "$IMAGE 는 안전합니다!" > "$FILENAME"
    fi
done


```

- **test용으로 매일 오전 8시 마다 실행**
```
* * * * * /home/username/trivy_slack_alert/trivy_scan.sh
```


## 결과

테스트를 위해 1분마다 실행하도록 cron 설정 후 결과 확인.
![image](https://github.com/user-attachments/assets/142a6db5-1d52-4ebe-ab3d-a74ffefdb02c)

![image](https://github.com/user-attachments/assets/76e4a102-9f2b-4b11-b7dd-71d342ad1c0f)

![image](https://github.com/user-attachments/assets/41b3b4a4-5a42-4251-b833-e5b0181b300c)

![image](https://github.com/user-attachments/assets/bb1e9cac-1455-426f-b464-09b0955a6ef8)

![image](https://github.com/user-attachments/assets/4a8c832b-86da-4f61-bb60-c36a1eb0e537)



