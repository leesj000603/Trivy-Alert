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
### 1. 환경 준비
먼저, Slack Webhook을 설정해야 한다.

Slack에서 원하는 채널로 이동한다.
앱 추가하기에서 Incoming Webhooks를 검색하여 설치한다.
Webhook URL을 생성하고 저장한다.

### 3. Dockerfile 및 Node.js 애플리케이션 작성
Dockerfile을 사용해 Node.js 애플리케이션을 만든다. 이 애플리케이션은 Trivy를 실행하고, 결과를 Slack으로 전송한다.
