(function (global) {
  const Recognition = global.SpeechRecognition || global.webkitSpeechRecognition;
  let recognition;
  let restartRecognition = false;
  let resultCallback;
  let errorCallback;

  function createRecognition() {
    if (!Recognition) return null;

    const instance = new Recognition();
    const finalTranscriptByIndex = new Map();
    instance.lang = global.navigator.language || 'en-IN';
    instance.continuous = true;
    instance.interimResults = true;
    instance.maxAlternatives = 1;
    instance.onresult = (event) => {
      let finalText = '';
      let interimText = '';
      for (let i = event.resultIndex; i < event.results.length; i += 1) {
        const result = event.results[i];
        if (result.isFinal) {
          const transcript = result[0].transcript;
          if (finalTranscriptByIndex.get(i) !== transcript) {
            finalText += transcript;
            finalTranscriptByIndex.set(i, transcript);
          }
        } else {
          interimText += result[0].transcript;
        }
      }
      if (resultCallback && (finalText || interimText)) {
        resultCallback(finalText, interimText);
      }
    };
    instance.onerror = (event) => {
      if (event.error !== 'no-speech' && errorCallback) {
        errorCallback(event.error || 'speech-recognition-failed');
      }
    };
    instance.onend = () => {
      if (recognition !== instance) return;
      if (restartRecognition) {
        global.setTimeout(() => {
          if (!restartRecognition) return;
          try {
            recognition = createRecognition();
            recognition.start();
          } catch (_) {
            // Chrome can emit onend while a restart is already in progress.
          }
        }, 250);
      }
    };
    return instance;
  }

  global.emergensyVoice = {
    isSupported: Boolean(Recognition && global.speechSynthesis),
    start(onResult, onError) {
      if (!Recognition) throw new Error('Speech recognition is not supported in this browser.');
      resultCallback = onResult;
      errorCallback = onError;
      restartRecognition = true;
      recognition = createRecognition();
      recognition.start();
    },
    stop() {
      restartRecognition = false;
      const current = recognition;
      recognition = null;
      if (current) current.stop();
      resultCallback = null;
      errorCallback = null;
    },
    speak(text, onDone, onError) {
      if (!global.speechSynthesis || !global.SpeechSynthesisUtterance) {
        onError('speech-synthesis-unavailable');
        return;
      }
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = global.navigator.language || 'en-IN';
      utterance.rate = 0.92;
      utterance.onend = onDone;
      utterance.onerror = (event) => onError(event.error || 'speech-synthesis-failed');
      global.speechSynthesis.speak(utterance);
    },
    stopSpeaking() {
      if (global.speechSynthesis) global.speechSynthesis.cancel();
    },
  };
})(globalThis);
