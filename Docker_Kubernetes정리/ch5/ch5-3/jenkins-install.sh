#!/usr/bin/env bash

# 기본 설정으로는 30분 넘게 사용하지 않으면 세션이 종료됨
# 추가 설정을 통해 세션의 유효 시간을 하루(1440분)로 변경하고
# 세션을 정리하는 시간 또한 하루(86400초)로 변경
jkopt1="--sessionTimeout=1440"
jkopt2="--sessionEviction=86400"

# 기본 설정으로는 시간대가 정확히 맞지 않아서 젠킨스를 통한 CI/CD 시에 명확한 작업을 구분하기 힘듬.
# 서울(Asia/Seoul) 시간대로 변경
jvopt1="-Duser.timezone=Asia/Seoul"

# 쿠버네티스를 위한 젠킨스 에이전트 노드 설정은 Pod Template이라는 곳을 통해서 설정값을 입력.
# 그런데 가상 머신인 마스터 노드가 다시 시작하게 되면, 이에 대한 설정이 초기화됨.
# 따라서 설정값을 미리 입력해둔 야믈 파일(jenkins-config.yaml)을 깃허브 저장소에서 받아오도록 설정
jvopt2="-Dcasc.jenkins.config=https://raw.githubusercontent.com/JngMkk/TIL/main/Docker%20%26%20k8s/Docker_Kubernetes%EC%A0%95%EB%A6%AC/ch5/ch5-3/jenkins-config.yaml"
jvopt3="-Dhudson.model.DownloadService.noSignatureCheck=true"

# edu 차트 저장소의 jenkins 차트를 사용해 jenkins 릴리스를 설치함
helm install jenkins edu/jenkins \

# PVC 동적 프로비저닝을 사용할 수 없는 가상 머신 기반의 환경이기 때문에
# 이미 만들어 놓은 jenkins라는 이름의 PVC를 사용하도록 설정
--set persistence.existingClaim=jenkins \

# 젠킨스 접속 시 사용할 관리자 비밀번호를 admin으로 설정.
# 이 값을 설정하지 않을 경우에는 설치 과정에서 젠킨스가 임의로 생성한 비밀번호를 사용
--set master.adminPassword=admin \

# 젠킨스의 컨트롤러 파드를 쿠버네티스 마스터 노드 m-k8s에 배치하도록 선택함
# nodeSelector는 nodeSelector의 뒤에 따라오는 문자열과 일치하는 레이블을 가진 노드에 파드를 스케줄링하겠다는 설정
--set master.nodeSelector."kubernetes\.io/hostname"=m-k8s \

# 윗 줄 옵션을 통해 m-k8s 노드에 파드를 배치할 것을 명시했지만 아래 3줄의 옵션이 없다면 마스터 노드에 파드를 배치할 수 없음.
# 현재 마스터 노드에는 파드를 배치하지 않도록 NoSchedule이라는 테인트가 설정된 상태이기 때문임.
# 테인트가 설정된 노드에 파드를 배치하려면 tolerations라는 옵션이 필요함.
# tolerations는 테인트에 예외를 설정하는 옵션.
# tolerations에는 예외를 설정한 테인트의 key와 effect, 연산자가 필요함.
# 아래 옵션은 key가 node-role.kubernetes.io/master이며 effect가 NoSchedule인 테인트가 존재할 때(Exists)
# 테인트를 예외 처리해 마스터 노드에 파드를 배치할 수 있도록 설정
--set master.tolerations[0].key=node-role.kubernetes.io/master \
--set master.tolerations[0].effect=NoSchedule \
--set master.tolerations[0].operator=Exists \

# 젠킨스를 구동하는 파드가 실행될 때 가질 유저 ID와, 그룹 ID를 설정함.
# 이때 사용되는 runAsUser는 사용자 ID, runAsGroup은 그룹 ID를 의미
--set master.runAsUser=1000 \
--set master.runAsGroup=1000 \

# 이후 젠킨스 버전에 따른 UI 변경을 막기 위해서 젠킨스 버전을 2.249.3으로 설정
--set master.tag=2.249.3-lts-centos7 \

# 차트로 생성되는 서비스의 타입을 로드밸런서로 설정해 외부 IP를 받아옴
--set master.serviceType=LoadBalancer \

# 젠킨스가 http상에서 구동되도록 포트를 80으로 지정
--set master.servicePort=80 \

# 젠킨스에 추가로 필요한 설정들을 변수로 받아옴
--set master.jenkinsOpts="$jkopt1 $jkopt2" \

# 젠킨스를 구동하기 위한 환경 설정에 필요한 것들을 변수로 호출해 젠킨스 실행 환경(JVM)에 적용
--set master.javaOpts="$jvopt1 $jvopt2 $jvopt3"