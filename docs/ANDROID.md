# Testar no celular Android

Passo a passo para gerar o APK de teste do Torneio Medieval e instalar no celular. O preset já está pronto em `export_presets.cfg` (nome **Android**): só arm64-v8a, paisagem, tela cheia (imersivo), permissão só de **vibração**, pacote `com.torneiomedieval.prototipo` (provisório, até o nome do jogo sair) e o ícone provisório `icon.svg`.

## O que falta instalar nesta máquina (uma vez só)

Verificado em 2026-10-11: os templates de desktop do Godot 4.7.2 estão instalados, mas faltam os de Android, o JDK e o Android SDK. Quando se tenta exportar, o Godot mostra exatamente estes erros:

```
No export template found ... android_debug.apk / android_release.apk
A valid Java SDK path is required in Editor Settings.
Invalid Android SDK path ... Missing 'platform-tools' / 'build-tools'
```

1. **Templates de exportação do Godot 4.7.2 (com Android).** Abra o projeto no editor: **Editor → Gerenciar Modelos de Exportação → Baixar e Instalar**. Isso baixa o pacote completo (desktop, Android, web) para `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
2. **JDK 17.** Instale o Eclipse Temurin 17 (adoptium.net), versão "JDK", para Windows x64. Anote a pasta (por exemplo, `C:\Program Files\Eclipse Adoptium\jdk-17...`).
3. **Android SDK.** O caminho mais simples é o Android Studio (developer.android.com/studio). Na primeira abertura, o assistente instala o SDK em `C:\Users\<você>\AppData\Local\Android\Sdk`. Depois, em **SDK Manager**, marque:
   - Android SDK Platform-Tools
   - Android SDK Build-Tools 35 (ou a mais nova)
   - Android SDK Command-line Tools (latest)
   - Android 15 (API 35), em SDK Platforms

   Sem o Android Studio: baixe só o "Command line tools only", descompacte em `...\Android\Sdk\cmdline-tools\latest\` e rode `sdkmanager "platform-tools" "build-tools;35.0.0" "platforms;android-35"`.
4. **Configurar o Godot.** No editor: **Editor → Configurações do Editor → Exportar → Android**:
   - `Java SDK Path` = pasta do JDK 17
   - `Android SDK Path` = `C:\Users\<você>\AppData\Local\Android\Sdk` (é o que já está configurado)
   - `Debug Keystore`: se o arquivo não existir, o Godot 4.7 cria um sozinho na primeira exportação de debug (senha `android`). Ele fica fora do repositório; nenhum keystore entra no git (`.gitignore`).

## Gerar o APK

No editor: **Projeto → Exportar… → Android → Exportar Projeto…**, desmarque "Exportar Com Depuração" só se quiser release (para testar, deixe marcado) e salve em `build/android/torneio_medieval.apk`.

Pela linha de comando, da raiz do projeto:

```bash
"D:\DEV\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --export-debug "Android" build/android/torneio_medieval.apk
```

A pasta `build/` e os `.apk` ficam fora do git.

## Instalar no celular

1. No celular: **Configurações → Sobre o telefone →** toque 7 vezes em **Número da versão** para liberar as Opções do desenvolvedor. Em **Opções do desenvolvedor**, ligue **Depuração USB**.
2. Ligue o celular no PC pelo cabo e aceite a pergunta "Permitir depuração USB?".
3. Instale:
   ```bash
   "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" install -r build\android\torneio_medieval.apk
   ```
   Alternativa sem cabo: copie o APK para o celular (Drive, WhatsApp para você mesmo) e abra; o Android vai pedir para permitir "instalar apps desconhecidos" para o app usado.
4. Mais rápido para testes repetidos: com o celular ligado e a depuração USB ativa, o editor mostra um botão do Android no canto superior direito (**Implantação com um clique**). Ele exporta, instala e abre o jogo de uma vez.

## O que olhar no teste

- O contador de FPS aparece embaixo, à esquerda, só em build de depuração (some no release).
- Toque na tela inteira com uma mão: pular a apresentação, largar quando a bandeira baixar, galopar no compasso (o brilho na barra de baixo), segurar/arrastar/soltar na mira, botão redondo da Investida depois que o anel carregar.
- Vibração no choque (permissão VIBRATE já pedida).
- Proporções: a interface deve caber sem corte em 16:9 até 20:9 (testado no PC com `SIZE=1600x720`).
- Para ver erros do jogo no PC enquanto ele roda no celular: `adb logcat -s godot`.

## Notificações locais (treino pronto, cavalo descansado)

O Godot não tem notificação local nativa no Android. O serviço `Notificacoes` (`game/scripts/services/servico_notificacoes.gd`) já monta a lista do que avisar e quando, e mostra o aviso dentro do jogo; para o aviso do sistema com o jogo fechado, instale um plugin Android de notificação local (por exemplo, um que exponha o singleton `LocalNotification` com `show(titulo, texto, segundos, id)`), ative-o no preset Android e confira o nome do singleton no serviço. Isso exige o build com Gradle (`gradle_build/use_gradle_build=true`).

## Release (mais tarde, Parte 3)

Release precisa de um keystore próprio (`keytool -genkeypair -v -keystore torneio.keystore -alias torneio -keyalg RSA -keysize 2048 -validity 10000`), guardado fora do repositório. As senhas vão em variáveis de ambiente (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER`, `..._PASSWORD`), nunca no `export_presets.cfg`. A Play Store pede AAB (`gradle_build/use_gradle_build=true` e `export_format=1`), o que exige instalar o template de build do Android no projeto.

## Anúncios premiados (3.19)

O autoload `Anuncios` (`game/scripts/services/servico_anuncios.gd`) procura um plugin de anúncios com singleton `AdMob` ou `GodotAdMob`, que tenha `show_rewarded(tipo)` e o sinal `rewarded(token)`. Ajuste os nomes conforme o plugin escolhido (por exemplo, o Godot AdMob plugin da Poing Studios), no preset Android com o build Gradle. Sem plugin, ele usa um provedor de **teste**, que só funciona em build de depuração. A recompensa só sai depois do "servidor" confirmar: hoje é `Jogador.recompensa_anuncio`; na Parte 3, uma Edge Function confere o token com o callback de verificação do AdMob (SSV). Consentimento de anúncios por região (GDPR/UMP) é da 3.9.

