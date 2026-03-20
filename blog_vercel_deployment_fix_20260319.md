# [DevLog] Flutter Web + Vercel + GitHub Actions 배포 오류 해결기

Vercel을 통해 Flutter Web 앱을 자동 배포하는 과정에서 겪은 경로 인식 오류와 이를 해결하기 위한 '아티팩트 구조화' 전략을 정리합니다.

## 1. 문제 상황 (The Error)

GitHub Actions를 통해 Flutter Web을 빌드하고 Vercel로 배포하려 할 때, 다음과 같은 경로 오류가 발생하며 배포가 중단되었습니다.

```text
Error: The provided path “~/work/NovelAIne/NovelAIne/frontend/build/web/frontend” does not exist.
To change your Project Settings, go to https://vercel.com/sorlros-projects/novelaine/settings
Error: The process '/usr/local/bin/npx' failed with exit code 1
```

분명 빌드 결과물은 `frontend/build/web`에 있는데, Vercel은 그 뒤에 `frontend`라는 경로를 한 번 더 붙여서 찾고 있었습니다.

---

## 2. 원인 분석: Vercel의 'Root Directory' 메커니즘

이 오류의 핵심은 Vercel 대시보드 설정의 **Root Directory**와 GitHub Actions의 **working-directory** 간의 충돌에 있었습니다.

1.  **Vercel 설정**: 현재 프로젝트의 Root Directory가 `frontend`로 설정되어 있습니다.
2.  **동작 방식**: Vercel CLI는 배포 명령이 실행되는 위치를 기준으로, 설정된 Root Directory인 `frontend` 폴더를 자동으로 탐색합니다.
3.  **충돌 발생**: 
    - 워크플로우에서 `working-directory: frontend/build/web`으로 설정.
    - Vercel은 해당 위치에서 `frontend` 폴더를 찾으려 함.
    - 결과적으로 `frontend/build/web/frontend`라는 존재하지 않는 경로를 참조하게 됨.

---

## 3. 해결을 위한 시도들

### 시도 1: `.vercel` 폴더 삭제 및 제외
실수로 커밋된 `frontend/.vercel/` 폴더가 프로젝트 설정을 꼬이게 할 수 있어 이를 삭제하고 `.gitignore`에 추가했습니다. 하지만 경로 오류 자체는 해결되지 않았습니다.

### 시도 2: `vercel-args` 경로 직접 지정
`vercel-args: 'frontend/build/web --prod'`와 같이 경로를 강제로 지정해 보았으나, Vercel은 여전히 프로젝트 루트 설정(`frontend`)을 기반으로 경로를 해석하여 실패했습니다.

---

## 4. 최종 해결책: '배포 전용 아티팩트(Artifact) 구조화'

가장 견고한 해결 방법은 **Vercel이 기대하는 물리적 구조를 배포 직전에 임시로 만들어주는 것**이었습니다. 이를 위해 '방안 C: 아티팩트 구조화 전략'을 채택했습니다.

### 적용된 워크플로우 전략
1.  `dist`라는 임시 루트 폴더를 만듭니다.
2.  그 안에 Vercel이 찾고 있는 `frontend`라는 이름의 폴더를 생성합니다.
3.  빌드된 결과물(`build/web/*`)을 `dist/frontend/`로 복사합니다.
4.  Vercel 배포를 `dist` 폴더에서 실행합니다.

이렇게 하면 Vercel은 `dist` 안에서 설정대로 `frontend` 폴더를 찾아 배포하게 되며, 우리가 원하는 빌드 파일들이 정확히 그 위치에 있게 됩니다.

### 최종 수정된 YAML (GitHub Action)

```yaml
      - name: Build Web
        run: |
          cd frontend
          flutter pub get
          flutter build web --release
          
          # Vercel의 Root Directory 설정(frontend)과 맞추기 위해 dist/frontend 구조 생성
          mkdir -p ../dist/frontend
          cp -r build/web/* ../dist/frontend/
          cp vercel.json ../dist/frontend/

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          # dist 폴더를 기준으로 배포 실행
          working-directory: dist
          vercel-args: '--prod'
```

---

## 5. 결론 및 고찰

CI/CD 환경에서는 로컬 빌드 결과물의 경로와 배포 플랫폼(Vercel, Render 등)이 기대하는 경로가 다를 때가 많습니다. 

이때 플랫폼 설정을 매번 바꾸는 것보다, **배포 직전에 플랫폼이 가장 좋아하는 형태(Artifact)로 데이터를 가공해서 건네주는 것**이 가장 안전하고 유지보수가 쉬운 방법이라는 교훈을 얻었습니다. 이 방식을 통해 경로 충돌 문제를 완벽하게 해결하고 안정적인 자동 배포 파이프라인을 구축했습니다.
