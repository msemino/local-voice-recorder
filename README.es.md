# Grabador de Voz Local → Portapapeles

> **Hablá libremente. Pensá en voz alta. El texto aparece en el portapapeles — 100% local, sin la nube.**

App de bandeja del sistema para Windows: grabás tu voz, la transcribe en tu propia GPU con [whisper.cpp](https://github.com/ggerganov/whisper.cpp), y el texto queda directo en el portapapeles. Un clic para grabar, un clic para parar.

---

## Por qué lo construí

La mayoría de los LLMs y asistentes de IA no aceptan audio, o la calidad de transcripción es mediocre. Necesitaba:

- **Hablarle a cualquier IA** (Claude, ChatGPT, modelos locales) — pegar la transcripción, listo.
- **Desarrollar ideas a la velocidad del habla**, no del tipeo. Pensar en voz alta es 3× más rápido.
- **Privacidad total.** La voz lleva emoción, tono y contexto que puede que no quieras en servidores de terceros. Whisper corre completamente en tu GPU local — ningún audio sale de tu máquina.
- **Funciona en cualquier app** — el portapapeles es la interfaz universal. Vale en cualquier browser, IDE, chat, cliente de mail.

---

## Uso

1. Buscá el **punto rojo** en la bandeja del sistema (puede estar debajo de la flechita `^`).
2. **Clic izquierdo** → empieza a grabar (el ícono parpadea en rojo).
3. Hablá. Sin límite de tiempo.
4. **Clic izquierdo de nuevo** → para la grabación, la GPU transcribe, el texto cae al portapapeles.
5. **Ctrl+V** donde quieras.

```
🔴 (listo)  →  🔴💓 (grabando)  →  🟡 (transcribiendo)  →  🟢 (listo → Ctrl+V)  →  🔴
```

---

## Instalación rápida

```powershell
git clone https://github.com/msemino/local-voice-recorder
cd local-voice-recorder
powershell -ExecutionPolicy Bypass -File src\install.ps1
```

Requiere: GPU NVIDIA con CUDA 12, [whisper.cpp](https://github.com/ggerganov/whisper.cpp) compilado con CUDA, modelo `ggml-large-v3.bin`, ffmpeg.

---

📖 [Full documentation in English](README.md)
