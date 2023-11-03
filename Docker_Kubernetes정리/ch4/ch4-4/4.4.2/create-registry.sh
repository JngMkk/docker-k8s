#!/usr/bin/env bash

# /etc/docker/certs.d/192.168.56.10:8443을 변수 certs에 설정
# 도커는 /etc/docker/certs.d 디렉터리 하위 경로에서
# 레지스트리 주소와 일치하는 디렉터리에 위치한 인증서를 찾아 레지스트리에 HTTPS로 접속
# 따라서 마스터 노드와 워커 노드에 인증서 디렉터리를 생성할 때 변수 certs를 인증서 디렉터리 경로로 사용
certs=/etc/docker/certs.d/192.168.56.10:8443

# docker run 부분에서 컨테이너 내부의 경로에 연결돼 레지스트리 이미지가 저장됨
mkdir /registry-image

# /etc/docker/certs/ 디렉터리를 생성
# 이 디렉터리는 레지스트리 서버의 인증서들을 보관
# REGISTRY_HTTP ADDR, TLS_CERTIFICATE 부분에서 레지스트리 컨테이너 내부에 연결돼
# 인증서를 컨테이너에서도 사용할 수 있게 함
mkdir /etc/docker/certs

# 변수 certs에 입력된 경로를 이용해 인증서를 보관할 디렉터리를 생성
mkdir -p $certs

# HTTPS로 접속을 하려면 서버의 정보가 담긴 인증서와 주고 받는 데이터를 암호화와 복호화할 때 사용하는 키가 필요함
# 인증서를 생성하는 요청서가 담긴 tls.csr 파일로 HTTPS 인증서인 tls.crt 파일과
# 암호화와 복호화에 사용하는 키인 tls.key 파일을 생성함
# $(dirname "$0")은 현재 셸 파일이 실행되는 경로
openssl req -x509 -config $(dirname "$0")/tls.csr -nodes -newkey rsa:4096 \
-keyout tls.key -out tls.crt -days 365 -extensions v3_req

# ssh 접속을 위한 비밀번호를 자동으로 입력하는 sshpass를 설치
# 별도의 설정이 없다면 ssh 접속 시 비밀번호를 사용자가 키보드로 직접 입력해야 함
# but, 사용자가 직접 비밀번호를 입력하면 자동화에 제약이 생김
yum install sshpass -y

# 워커 노드에 대한 인증서 디렉터리를 생성하고 인증서를 복사하는 작업
for i in {1..3}
  do

  	# 워커 노드에 인증서 디렉터리 생성
  	# sshpass를 이용해 비밀번호를 키보드로 입력하지 않고 vagrant를 ssh 접속 비밀번호로 전달
  	# ssh 명령어로 StrictHostKeyChecking=no 옵션을 전달해
    # ssh로 접속할 때 키를 확인하는 절차를 생략하고 바로 명령을 전달할 수 있게 함
    sshpass -p vagrant ssh -o StrictHostKeyChecking=no root@192.168.56.10$i mkdir -p $certs
    
	# 레지스트리 서버의 인증서 파일을 워커 노드로 복사함    
    sshpass -p vagrant scp tls.crt 192.168.56.10$i:$certs
  done

# openssl ...에서 생성한 레지스트리 서버의 인증서 파일인 tls.crt와
# 암호화와 복호화에 사용하는 키인 tls.key 중에 tls.crt를 변수 certs 디렉터리로 복사하고
# tls.crt와 tls.key를 /etc/docker/certs/ 디렉터리로 옮김.
# 인증서 관련 파일들을 사용해 레지스트리 컨테이너에 들어오는 요청을 인증하고
# 인증서가 설치된 호스트에서만 레지스트리에 접근할 수 있게 함
cp tls.crt $certs
mv tls.* /etc/docker/certs

# 컨테이너를 백그라운드에서 데몬으로 실행하고, 정지되면 자동으로 재시작
docker run -d \
  --restart=always \
  --name registry \
  
  # 사설 인증서와 관련된 파일들이 위치한 디렉터리를 컨테이너 내부에서 사용할 수 있도록
  # -v 옵션으로 컨테이너 내부의 docker-in-certs 디렉터리와 연결
  # 인증서 정보는 외부에서 임의 변경할 수 없도록 안전하게 보관해야 하므로 ro(Read-Only) 옵션으로 설정
  -v /etc/docker/certs:/docker-in-certs:ro \
  
  # 레지스트리에 컨테이너 이미지가 계속 저장될 수 있도록
  # 호스트에 저장 공간으로 설정한 registry-image 디렉터리를 컨테이너 내부의 디렉터리와 연결
  # 사설 도커 레지스트리는 사용자가 push한 데이터를 내부의 디렉터리에 기본으로 저장
  # 별도의 외부 디렉터리에 데이터를 저장하지 않는다면 컨테이너가 새로 구동될 때마다 데이터가 삭제됨
  -v /registry-image:/var/lib/registry \
  
  # 레지스트리가 요청을 받아들이는 포트로 443포트를 설정
  # 443 포트는 HTTPS로 접속할 때 사용하는 기본 포트
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  
  # 레지스트리가 사용할 HTTPS 인증서의 경로를 설정
  # 연결한 경로 내부에 있는 tls.crt 파일을 HTTPS 인증서로 사용
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/docker-in-certs/tls.crt \
  
  # HTTPS로 데이터를 주고받을 때 데이터의 암호화와 복호화를 위한 키로 사용할 파일의 경로를
  # 연결한 경로 내부에 있는 tls.key로 설정
  -e REGISTRY_HTTP_TLS_KEY=/docker-in-certs/tls.key \
  
  # 호스트 컴퓨터의 8443번 포트와 컨테이너 내부의 443번 포트를 연결
  # 외부에서 호스트 컴퓨터의 8443번 포트로 요청을 보내면 사설 도커 레지스트리 내부의 443번 포트로 전달
  -p 8443:443 \
  
  # 도커 허브에 있는 registry 이미지로 레지스트리 컨테이너를 생성
  # 태그 2를 넣어서 레지스트리.* 버전 이미지를 사용한다는 것을 명시
  registry:2