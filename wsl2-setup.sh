#!/bin/bash

# WSL2 환경 설정 스크립트
echo "=== WSL2 환경 설정 ==="

# Vagrant WSL 접근 활성화
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1
echo "VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1 설정 완료"

# Windows 파일시스템 경로 확인
echo "현재 작업 디렉토리: $(pwd)"
echo "Windows 경로: /mnt/c/worksapce/tz-k8s-vagrant"

# Vagrant 버전 확인
echo "Vagrant 버전:"
vagrant --version

# VirtualBox 접근 확인
echo "VirtualBox 접근 확인:"
VBoxManage --version 2>/dev/null && echo "VirtualBox 접근 가능" || echo "VirtualBox 접근 불가 - Windows에서 VirtualBox 설치 필요"

# 네트워크 인터페이스 확인
echo "사용 가능한 네트워크 인터페이스:"
ipconfig /all 2>/dev/null | grep -E "Ethernet adapter|Wireless LAN adapter" || echo "Windows 네트워크 인터페이스 확인 불가"

echo "=== 설정 완료 ==="
echo "이제 bash bootstrap.sh를 실행할 수 있습니다." 