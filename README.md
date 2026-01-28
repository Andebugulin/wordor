# Wordor

Boosted translator with industry standard memory algorithm, made to help you learn translations right away!

# Idea

I am language learner, and when I learn a new language every now and then I come across the cool sounding words (for example **cariño** in spanish),
then I would go to translate it, and then it would actually be something interesting that I would want to remember, but I never put it into Anki or any other learning vocab tool, so I kinda forget about it. That's where idea struck, what if just have a translator, then in the translator I would basically right away have a functionality to say that I want to remember it and my translator would become learning tool itself too.

## Features

### Voice Input

### Smart Translation (Powered by Deepl API)

### Spaced Repetition

- **4-level hint system** (with gemini AI, optional):
  1. Example sentence in source language
  2. Meaning explanation in target language
  3. First letter hint
  4. Full answer reveal

### Optional Notifications

## Screenshots

## Getting Started

### Prerequisites

#### For normal usage

- Deepl API key
- Gemini API key (optional, for AI hints)
- Download APK

#### For self develop/install

- Flutter SDK 3.10 or higher
- Android Studio or VS Code
- Android device/emulator (Android 7.0+)
- DeepL API key (required)
- Gemini API key (optional, for AI hints)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/Andebugulin/wordor.git
   cd wordor
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Generate Database .g.dart**

   ```bash
   dart run build_runner build --delete-conflicting-outputs

   ```

4. **Set up API keys**

   You'll need to get API keys:

   - **DeepL API** (required): Get free key at https://www.deepl.com/pro-api
   - **Gemini API** (optional): Get free key at https://ai.google.dev

5. **Run the app**

   ```bash
   flutter run
   ```

6. **Enter your API keys**

   Put your API keys into the setup screen or later in the settings (Gemini API key)

## How to Use

### Translating Words

1. **Type or Speak**

   - Tap the microphone icon to use voice input
   - Or type your word/phrase

2. **Select Languages**

   - Tap language buttons to change source/target
   - Recently used languages appear first

3. **Save for Review**
   - Translate your word
   - Tap "Save" to add it to recall list
   - Word will appear for review based on spaced repetition

### Reviewing Words

1. **Check Due Words**

   - Badge shows number of due words
   - Open "Recall" tab to start review

2. **Test Your Memory**

   - Try to recall the translation
   - Use hints if needed (costs review efficiency)

3. **Mark Your Response**
   - "I Know" - Word moves to longer interval
   - "Hint Helped" - Moderate interval increase
   - "Forgot" - Word resets to short interval

### Using Hints

**Without AI (2 hints):**

1. First letter of translation
2. Full answer reveal

**With AI (4 hints):**

1. Example sentence using the word (in source language)
2. Meaning explanation (in target language, without using the word)
3. First letter of translation
4. Full answer reveal

## Technical Stack

### Core Technologies

- **Flutter** - Cross-platform UI framework
- **Riverpod** - State management
- **Drift** - SQLite database ORM
- **SQLite** - Local data storage

### APIs & Services

- **DeepL API** - Translation service
- **Gemini API** - AI-powered hints and examples
- **Android Alarm Manager** - Background task scheduling
- **Flutter Local Notifications** - Notification system
- **Speech to Text** - Voice input recognition

### Key Packages

```yaml
dependencies:
  drift: ^2.14.0
  flutter_riverpod: ^2.4.0
  flutter_local_notifications: ^17.0.0
  android_alarm_manager_plus: ^4.0.3
  speech_to_text: ^7.0.0
  http: ^1.1.0
  timezone: ^0.9.0
```

## Project Structure

```
lib/
├── data/
│   ├── database.dart                       # Drift database schema
│   ├── deepl_service.dart                  # DeepL API integration
│   └── api_key_storage.dart                # Secure API key storage
├── services/
│   ├── notification_service.dart           # Notification management
│   ├── background_notification_service.dart# Background tasks
│   ├── gemini_service.dart                 # Gemini AI integration
│   └── tts_service.dart                    # Text-to-speech
├── ui/
│   ├── home_screen.dart                    # Main navigation
│   ├── translate_screen.dart               # Translation interface
│   ├── recall_screen.dart                  # Spaced repetition UI
│   ├── settings_screen.dart                # App settings
│   ├── word_library_screen.dart            # Saved words list
│   └── language_picker.dart                # Language selection
├── providers/
│   └── app_providers.dart                  # Riverpod providers
├── theme.dart                              # App theming
└── main.dart                               # App entry point
```

## Configuration

### Database Schema

**Words Table:**

- Source word/phrase
- Translation
- Language pair
- Example sentence (optional)
- Creation date

**Recalls Table:**

- Word reference
- Next review date
- Current interval
- Ease factor
- Review count

**Translation History:**

- All translations
- Saved status
- Timestamp

### Spaced Repetition Algorithm

- **Initial interval**: 1 day
- **Success multiplier**: 2.5x
- **Partial success**: 1.5x
- **Failure**: Reset to 1 day
- **Maximum interval**: ~100 days

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

**Made with ❤️**

Claude AI was used in the development of this project, all the code has been manually verified and tested, before deployment!
