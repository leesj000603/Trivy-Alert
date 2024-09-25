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
먼저, Slack Webhook을 설정해야 한다.

- **Slack에서 원하는 채널로 이동한다.**
    앱 추가하기에서 Incoming Webhooks를 검색하여 설치한다.
    ![image](https://github.com/user-attachments/assets/bc48e369-f499-4a32-95e8-48fe58f2eb69)

- **Webhook URL을 생성하고 저장한다.**
    ![image](https://github.com/user-attachments/assets/125ce9c1-4a33-42e8-97df-97164d9ad27f)
    
    ![image](https://github.com/user-attachments/assets/14e9360a-44ec-47fa-857b-8d328c84f97f)
    
    이후 수신 웹후크 통합 앱 추가를 누르면 URL이 생성된다.

### 2. Dockerfile 및 Node.js 애플리케이션 작성
Dockerfile을 사용해 Node.js 애플리케이션을 만든다. 이 애플리케이션은 Trivy를 실행하고, 결과를 Slack으로 전송한다.

- **Dockerfile**
```
# Dockerfile
FROM node:14

# 작업 디렉토리 설정
WORKDIR /usr/src/app

# 종속성 파일 복사 및 설치
COPY package*.json ./
RUN npm install

# 애플리케이션 파일 복사
COPY . .

# Cron 패키지 설치
RUN apt-get update && apt-get install -y cron

# Cronjob 추가
COPY crontab /etc/cron.d/trivy-cron

# Cronjob 권한 설정
RUN chmod 0644 /etc/cron.d/trivy-cron

# Cron 서비스 시작
CMD ["cron", "-f"]

```

- **pakage.json 파일**
```
{
    "name": "trivy-slack-alert",
    "version": "1.0.0",
    "main": "trivyNotifier.js",  
    "scripts": {
      "start": "node trivyNotifier.js" 
    },
    "dependencies": {
      "axios": "^0.21.1"
    }
}
```

- **TrivyAlert.js 파일**
```
const { exec } = require('child_process');
const axios = require('axios');

const SLACK_WEBHOOK_URL = 'https://hooks.slack.com/services/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'; // Slack Webhook URL 입력

// 실행 중인 Docker 컨테이너의 이름을 가져오는 함수
function getRunningContainers(callback) {
  exec('docker ps --format "{{.Names}}"', (error, stdout, stderr) => {
    if (error) {
      console.error(`Error fetching running containers: ${error}`);
      return callback(error, null);
    }
    const containers = stdout.trim().split('\n');
    callback(null, containers);
  });
}

// 각 컨테이너에 대해 Trivy를 실행하는 함수
function scanContainer(containerName) {
  exec(`trivy image --format json ${containerName}`, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error executing Trivy for ${containerName}: ${error}`);
      return;
    }

    const result = JSON.parse(stdout);
    let vulnerabilities = result[0]?.Vulnerabilities || [];
    let criticalIssues = vulnerabilities.filter(vuln => vuln.Severity === 'CRITICAL');

    if (criticalIssues.length > 0) {
      const message = `⚠️ Trivy Alert! Critical vulnerabilities found in ${containerName}:\n\n` +
        criticalIssues.map(issue => `- ${issue.VulnerabilityID} (${issue.Title})`).join('\n');

      axios.post(SLACK_WEBHOOK_URL, { text: message })
        .then(() => console.log(`Alert sent to Slack for ${containerName}!`))
        .catch(err => console.error(`Error sending to Slack for ${containerName}:`, err));
    } else {
      console.log(`No critical vulnerabilities found in ${containerName}.`);
    }
  });
}

// 실행 중인 컨테이너 가져오기
getRunningContainers((error, containers) => {
  if (error) return;

  containers.forEach(container => {
    scanContainer(container);
  });
});

```

- **test용으로 crontab 2분마다 실행**
```
# crontab (2분마다 실행)
*/2 * * * * node /usr/src/app/trivyNotifier.js >> /var/log/trivy.log 2>&1****
```


- **빌드명령**
```
docker build -t trivy-slack-alert .
```
