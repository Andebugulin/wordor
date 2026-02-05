import 'dart:convert';
import 'package:http/http.dart' as http;

enum AIProvider { huggingface, gemini }

/// Language complexity level for generated content
enum ComplexityLevel {
  a1(1, 'A1 - Beginner'),
  a2(2, 'A2 - Elementary'),
  b1(3, 'B1 - Intermediate'),
  b2(4, 'B2 - Upper Intermediate'),
  c1(5, 'C1 - Advanced'),
  c2(6, 'C2 - Proficient');

  final int level;
  final String label;
  const ComplexityLevel(this.level, this.label);
}

class AIHintService {
  final String apiKey;
  final AIProvider provider;
  final String? customModel;
  final ComplexityLevel complexity;

  static const String hfBaseUrl = 'https://router.huggingface.co/v1';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static const String defaultHFModel =
      'Qwen/Qwen2.5-7B-Instruct:featherless-ai';

  static const List<HFModel> recommendedModels = [
    HFModel(
      name: 'Qwen 2.5 7B',
      id: 'Qwen/Qwen2.5-7B-Instruct:featherless-ai',
      description: 'Excellent for multiple languages',
      recommended: false,
    ),
    HFModel(
      name: 'Mistral 7B',
      id: 'mistralai/Mistral-7B-Instruct-v0.2:featherless-ai',
      description: 'Fast and accurate, great for hints',
      recommended: true,
    ),
    HFModel(
      name: 'Custom Model',
      id: '__custom__',
      description: 'Enter your own model string',
      recommended: false,
    ),
  ];

  AIHintService(
    this.apiKey,
    this.provider, {
    this.customModel,
    this.complexity = ComplexityLevel.b1,
  });

  String get activeModel => customModel ?? defaultHFModel;

  // =========================
  // PUBLIC API
  // =========================

  /// Generate example sentences using the word
  Future<String> generateExample({
    required String word,
    required String sourceLang,
  }) async {
    final prompt = _getExamplePrompt(word, sourceLang);

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _callAI(prompt);
        final cleaned = _cleanResponse(response);

        // Verify the response
        final verification = _verifyExampleResponse(cleaned, word, sourceLang);

        if (verification.isValid) {
          return verification.correctedText;
        }

        // If invalid, try with stricter prompt
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      } catch (e) {
        if (attempt == 2) rethrow;
        await Future.delayed(Duration(milliseconds: 500));
      }
    }

    // Fallback: return something rather than crash
    return _getFallbackExample(word, sourceLang);
  }

  /// Generate explanation without revealing the word
  Future<String> generateExplanation({
    required String word,
    required String translation,
    required String targetLang,
  }) async {
    final prompt = _getExplanationPrompt(translation, targetLang);

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _callAI(prompt);
        final cleaned = _cleanResponse(response);

        // Verify the response
        final verification = _verifyExplanationResponse(
          cleaned,
          translation,
          targetLang,
        );

        if (verification.isValid) {
          return verification.correctedText;
        }

        // If invalid, try with stricter prompt
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      } catch (e) {
        if (attempt == 2) rethrow;
        await Future.delayed(Duration(milliseconds: 500));
      }
    }

    // Fallback: return something rather than crash
    return _getFallbackExplanation(translation, targetLang);
  }

  /// Validate API key
  Future<Map<String, dynamic>> validateApiKey() async {
    try {
      await _callAI('Say OK.');
      return {'valid': true, 'message': 'API key is valid'};
    } catch (e) {
      return {'valid': false, 'message': e.toString()};
    }
  }

  // =========================
  // LANGUAGE-SPECIFIC PROMPTS
  // =========================

  String _getExamplePrompt(String word, String langCode) {
    final complexityDesc = _getComplexityDescription(langCode);

    final prompts = {
      'EN':
          '''Write 2-3 natural example sentences using the word "$word".

Requirements:
- Each sentence must be 5-15 words long
- Use simple, everyday vocabulary (${complexityDesc})
- Write ONLY in English
- The word "$word" must appear naturally in each sentence
- Do not translate or explain
- Output only the sentences, nothing else''',

      'FI':
          '''Kirjoita 2-3 esimerkkivirkettä, joissa käytetään sanaa "$word".

Vaatimukset:
- Jokaisen virkkeen täytyy olla 5-15 sanaa pitkä
- Käytä yksinkertaista, arkipäiväistä sanastoa (${complexityDesc})
- Kirjoita VAIN suomeksi
- Sanan "$word" täytyy esiintyä luonnollisesti jokaisessa virkkeessä
- Älä käännä tai selitä
- Tulosta vain virkkeet, ei mitään muuta''',

      'DE':
          '''Schreibe 2-3 natürliche Beispielsätze mit dem Wort "$word".

Anforderungen:
- Jeder Satz muss 5-15 Wörter lang sein
- Verwende einfaches, alltägliches Vokabular (${complexityDesc})
- Schreibe NUR auf Deutsch
- Das Wort "$word" muss in jedem Satz natürlich vorkommen
- Nicht übersetzen oder erklären
- Gib nur die Sätze aus, nichts anderes''',

      'ES':
          '''Escribe 2-3 oraciones de ejemplo naturales usando la palabra "$word".

Requisitos:
- Cada oración debe tener entre 5-15 palabras
- Usa vocabulario simple y cotidiano (${complexityDesc})
- Escribe SOLO en español
- La palabra "$word" debe aparecer naturalmente en cada oración
- No traduzcas ni expliques
- Escribe solo las oraciones, nada más''',

      'FR':
          '''Écris 2-3 phrases d'exemple naturelles utilisant le mot "$word".

Exigences:
- Chaque phrase doit contenir 5-15 mots
- Utilise un vocabulaire simple et quotidien (${complexityDesc})
- Écris UNIQUEMENT en français
- Le mot "$word" doit apparaître naturellement dans chaque phrase
- Ne traduis pas et n'explique pas
- Écris seulement les phrases, rien d'autre''',

      'IT':
          '''Scrivi 2-3 frasi di esempio naturali usando la parola "$word".

Requisiti:
- Ogni frase deve essere lunga 5-15 parole
- Usa un vocabolario semplice e quotidiano (${complexityDesc})
- Scrivi SOLO in italiano
- La parola "$word" deve apparire naturalmente in ogni frase
- Non tradurre o spiegare
- Scrivi solo le frasi, nient'altro''',

      'PT':
          '''Escreva 2-3 frases de exemplo naturais usando a palavra "$word".

Requisitos:
- Cada frase deve ter 5-15 palavras
- Use vocabulário simples e cotidiano (${complexityDesc})
- Escreva APENAS em português
- A palavra "$word" deve aparecer naturalmente em cada frase
- Não traduza ou explique
- Escreva apenas as frases, nada mais''',

      'NL':
          '''Schrijf 2-3 natuurlijke voorbeeldzinnen met het woord "$word".

Vereisten:
- Elke zin moet 5-15 woorden lang zijn
- Gebruik eenvoudige, alledaagse woordenschat (${complexityDesc})
- Schrijf ALLEEN in het Nederlands
- Het woord "$word" moet natuurlijk voorkomen in elke zin
- Vertaal of leg niet uit
- Geef alleen de zinnen weer, niets anders''',

      'PL':
          '''Napisz 2-3 naturalne zdania przykładowe używając słowa "$word".

Wymagania:
- Każde zdanie musi mieć 5-15 słów
- Używaj prostego, codziennego słownictwa (${complexityDesc})
- Pisz TYLKO po polsku
- Słowo "$word" musi pojawić się naturalnie w każdym zdaniu
- Nie tłumacz ani nie wyjaśniaj
- Wypisz tylko zdania, nic więcej''',

      'RU':
          '''Напиши 2-3 естественных примера предложений со словом "$word".

Требования:
- Каждое предложение должно содержать 5-15 слов
- Используй простую, повседневную лексику (${complexityDesc})
- Пиши ТОЛЬКО на русском языке
- Слово "$word" должно естественно встречаться в каждом предложении
- Не переводи и не объясняй
- Выведи только предложения, ничего больше''',

      'CS':
          '''Napiš 2-3 přirozené příkladové věty se slovem "$word".

Požadavky:
- Každá věta musí mít 5-15 slov
- Použij jednoduchou, každodenní slovní zásobu (${complexityDesc})
- Piš POUZE česky
- Slovo "$word" se musí přirozeně vyskytovat v každé větě
- Nepřekládej ani nevysvětluj
- Vypiš pouze věty, nic jiného''',

      'SV':
          '''Skriv 2-3 naturliga exempelmeningar med ordet "$word".

Krav:
- Varje mening måste vara 5-15 ord lång
- Använd enkelt, vardagligt ordförråd (${complexityDesc})
- Skriv ENDAST på svenska
- Ordet "$word" måste förekomma naturligt i varje mening
- Översätt eller förklara inte
- Skriv bara meningarna, inget annat''',

      'DA':
          '''Skriv 2-3 naturlige eksempelsætninger med ordet "$word".

Krav:
- Hver sætning skal være 5-15 ord lang
- Brug simpelt, dagligdags ordforråd (${complexityDesc})
- Skriv KUN på dansk
- Ordet "$word" skal forekomme naturligt i hver sætning
- Oversæt eller forklar ikke
- Skriv kun sætningerne, intet andet''',

      'NB':
          '''Skriv 2-3 naturlige eksempelsetninger med ordet "$word".

Krav:
- Hver setning må være 5-15 ord lang
- Bruk enkelt, hverdagslig ordforråd (${complexityDesc})
- Skriv KUN på norsk
- Ordet "$word" må forekomme naturlig i hver setning
- Ikke oversett eller forklar
- Skriv bare setningene, ingenting annet''',

      'TR':
          '''"$word" kelimesini kullanarak 2-3 doğal örnek cümle yaz.

Gereksinimler:
- Her cümle 5-15 kelime uzunluğunda olmalı
- Basit, günlük kelime dağarcığı kullan (${complexityDesc})
- SADECE Türkçe yaz
- "$word" kelimesi her cümlede doğal olarak görünmeli
- Çevirme veya açıklama yapma
- Sadece cümleleri yaz, başka bir şey yazma''',

      'AR':
          '''اكتب 2-3 جمل أمثلة طبيعية باستخدام كلمة "$word".

المتطلبات:
- يجب أن تحتوي كل جملة على 5-15 كلمة
- استخدم مفردات بسيطة ويومية (${complexityDesc})
- اكتب باللغة العربية فقط
- يجب أن تظهر كلمة "$word" بشكل طبيعي في كل جملة
- لا تترجم أو تشرح
- اكتب الجمل فقط، لا شيء آخر''',

      'JA':
          '''「$word」という言葉を使って、2-3つの自然な例文を書いてください。

要件:
- 各文は5-15語でなければなりません
- 簡単な日常的な語彙を使用してください (${complexityDesc})
- 日本語のみで書いてください
- 「$word」という言葉が各文に自然に現れる必要があります
- 翻訳や説明をしないでください
- 文のみを出力し、他のものは何も出力しないでください''',

      'KO':
          '''"$word"라는 단어를 사용하여 2-3개의 자연스러운 예문을 작성하세요.

요구사항:
- 각 문장은 5-15개의 단어여야 합니다
- 간단하고 일상적인 어휘를 사용하세요 (${complexityDesc})
- 한국어로만 작성하세요
- "$word"라는 단어가 각 문장에 자연스럽게 나타나야 합니다
- 번역하거나 설명하지 마세요
- 문장만 출력하고 다른 것은 출력하지 마세요''',

      'ZH':
          '''使用"$word"这个词写2-3个自然的例句。

要求:
- 每个句子必须是5-15个字
- 使用简单的日常词汇 (${complexityDesc})
- 只用中文写
- "$word"这个词必须自然地出现在每个句子中
- 不要翻译或解释
- 只输出句子，不要输出其他内容''',

      'EL':
          '''Γράψε 2-3 φυσικές παραδειγματικές προτάσεις με τη λέξη "$word".

Απαιτήσεις:
- Κάθε πρόταση πρέπει να είναι 5-15 λέξεις
- Χρησιμοποίησε απλό, καθημερινό λεξιλόγιο (${complexityDesc})
- Γράψε ΜΟΝΟ στα ελληνικά
- Η λέξη "$word" πρέπει να εμφανίζεται φυσικά σε κάθε πρόταση
- Μην μεταφράσεις ή εξηγήσεις
- Γράψε μόνο τις προτάσεις, τίποτα άλλο''',

      'HU':
          '''Írj 2-3 természetes példamondatot a "$word" szóval.

Követelmények:
- Minden mondatnak 5-15 szónak kell lennie
- Használj egyszerű, hétköznapi szókincset (${complexityDesc})
- Írj CSAK magyarul
- A "$word" szónak természetesen kell megjelennie minden mondatban
- Ne fordítsd le és ne magyarázd
- Csak a mondatokat írd ki, semmi mást''',

      'RO':
          '''Scrie 2-3 propoziții exemplu naturale folosind cuvântul "$word".

Cerințe:
- Fiecare propoziție trebuie să aibă 5-15 cuvinte
- Folosește vocabular simplu, cotidian (${complexityDesc})
- Scrie DOAR în română
- Cuvântul "$word" trebuie să apară natural în fiecare propoziție
- Nu traduce și nu explica
- Scrie doar propozițiile, nimic altceva''',

      'BG':
          '''Напиши 2-3 естествени примерни изречения с думата "$word".

Изисквания:
- Всяко изречение трябва да съдържа 5-15 думи
- Използвай прост, ежедневен речник (${complexityDesc})
- Пиши САМО на български
- Думата "$word" трябва да се появява естествено във всяко изречение
- Не превеждай и не обяснявай
- Изведи само изреченията, нищо друго''',

      'UK':
          '''Напиши 2-3 природних приклади речень зі словом "$word".

Вимоги:
- Кожне речення повинно містити 5-15 слів
- Використовуй просту, повсякденну лексику (${complexityDesc})
- Пиши ТІЛЬКИ українською
- Слово "$word" повинно природно зустрічатися в кожному реченні
- Не перекладай і не пояснюй
- Виведи тільки речення, нічого більше''',

      'SK':
          '''Napíš 2-3 prirodzené príkladové vety so slovom "$word".

Požiadavky:
- Každá veta musí mať 5-15 slov
- Použi jednoduchú, každodennú slovnú zásobu (${complexityDesc})
- Píš IBA po slovensky
- Slovo "$word" sa musí prirodzene vyskytovať v každej vete
- Neprekládaj ani nevysvetľuj
- Vypíš iba vety, nič iné''',

      'SL':
          '''Napiši 2-3 naravne primerne stavke z besedo "$word".

Zahteve:
- Vsak stavek mora biti dolg 5-15 besed
- Uporabi preprost, vsakdanji besedni zaklad (${complexityDesc})
- Piši SAMO v slovenščini
- Beseda "$word" se mora naravno pojavljati v vsakem stavku
- Ne prevajaj in ne razlagaj
- Izpiši samo stavke, nič drugega''',

      'ET':
          '''Kirjuta 2-3 loomulikku näitelausett sõnaga "$word".

Nõuded:
- Iga lause peab olema 5-15 sõna pikkune
- Kasuta lihtsat, igapäevast sõnavara (${complexityDesc})
- Kirjuta AINULT eesti keeles
- Sõna "$word" peab igas lauses loomulikult esinema
- Ära tõlgi ega seleta
- Väljasta ainult laused, mitte midagi muud''',

      'LT':
          '''Parašyk 2-3 natūralius pavyzdžių sakinius su žodžiu "$word".

Reikalavimai:
- Kiekvienas sakinys turi būti 5-15 žodžių ilgio
- Naudok paprastą, kasdienį žodyną (${complexityDesc})
- Rašyk TIK lietuviškai
- Žodis "$word" turi natūraliai pasirodyti kiekviename sakinyje
- Neversk ir neaiškink
- Išvesk tik sakinius, nieko daugiau''',

      'LV':
          '''Uzraksti 2-3 dabīgus piemēru teikumus ar vārdu "$word".

Prasības:
- Katram teikumam jābūt 5-15 vārdu garam
- Izmanto vienkāršu, ikdienas vārdu krājumu (${complexityDesc})
- Raksti TIKAI latviski
- Vārdam "$word" jāparādās dabiski katrā teikumā
- Netulko un neizskaidro
- Izvadi tikai teikumus, neko citu''',

      'ID':
          '''Tulis 2-3 kalimat contoh alami menggunakan kata "$word".

Persyaratan:
- Setiap kalimat harus sepanjang 5-15 kata
- Gunakan kosakata sederhana sehari-hari (${complexityDesc})
- Tulis HANYA dalam bahasa Indonesia
- Kata "$word" harus muncul secara alami di setiap kalimat
- Jangan terjemahkan atau jelaskan
- Keluarkan hanya kalimat, tidak ada yang lain''',
    };

    return prompts[langCode] ?? prompts['EN']!;
  }

  String _getExplanationPrompt(String word, String langCode) {
    final complexityDesc = _getComplexityDescription(langCode);

    final prompts = {
      'EN':
          '''Explain the meaning of the word "$word" without using the word "$word" itself.

Requirements:
- Your explanation must be 10-30 words long
- Use simple, everyday vocabulary (${complexityDesc})
- Write ONLY in English
- Do not use the word "$word" anywhere in your explanation
- Write like a dictionary definition
- Output only the explanation, nothing else''',

      'FI':
          '''Selitä sanan "$word" merkitys käyttämättä itse sanaa "$word".

Vaatimukset:
- Selityksesi täytyy olla 10-30 sanaa pitkä
- Käytä yksinkertaista, arkipäiväistä sanastoa (${complexityDesc})
- Kirjoita VAIN suomeksi
- Älä käytä sanaa "$word" missään selityksessäsi
- Kirjoita kuin sanakirjamääritelmä
- Tulosta vain selitys, ei mitään muuta''',

      'DE':
          '''Erkläre die Bedeutung des Wortes "$word", ohne das Wort "$word" selbst zu verwenden.

Anforderungen:
- Deine Erklärung muss 10-30 Wörter lang sein
- Verwende einfaches, alltägliches Vokabular (${complexityDesc})
- Schreibe NUR auf Deutsch
- Verwende das Wort "$word" nirgendwo in deiner Erklärung
- Schreibe wie eine Wörterbuchdefinition
- Gib nur die Erklärung aus, nichts anderes''',

      'ES':
          '''Explica el significado de la palabra "$word" sin usar la palabra "$word".

Requisitos:
- Tu explicación debe tener entre 10-30 palabras
- Usa vocabulario simple y cotidiano (${complexityDesc})
- Escribe SOLO en español
- No uses la palabra "$word" en ninguna parte de tu explicación
- Escribe como una definición de diccionario
- Escribe solo la explicación, nada más''',

      'FR':
          '''Explique la signification du mot "$word" sans utiliser le mot "$word" lui-même.

Exigences:
- Ton explication doit contenir 10-30 mots
- Utilise un vocabulaire simple et quotidien (${complexityDesc})
- Écris UNIQUEMENT en français
- N'utilise pas le mot "$word" dans ton explication
- Écris comme une définition de dictionnaire
- Écris seulement l'explication, rien d'autre''',

      'IT':
          '''Spiega il significato della parola "$word" senza usare la parola "$word" stessa.

Requisiti:
- La tua spiegazione deve essere lunga 10-30 parole
- Usa un vocabolario semplice e quotidiano (${complexityDesc})
- Scrivi SOLO in italiano
- Non usare la parola "$word" da nessuna parte nella tua spiegazione
- Scrivi come una definizione di dizionario
- Scrivi solo la spiegazione, nient'altro''',

      'PT':
          '''Explique o significado da palavra "$word" sem usar a palavra "$word".

Requisitos:
- Sua explicação deve ter 10-30 palavras
- Use vocabulário simples e cotidiano (${complexityDesc})
- Escreva APENAS em português
- Não use a palavra "$word" em nenhum lugar da sua explicação
- Escreva como uma definição de dicionário
- Escreva apenas a explicação, nada mais''',

      'NL':
          '''Leg de betekenis van het woord "$word" uit zonder het woord "$word" zelf te gebruiken.

Vereisten:
- Je uitleg moet 10-30 woorden lang zijn
- Gebruik eenvoudige, alledaagse woordenschat (${complexityDesc})
- Schrijf ALLEEN in het Nederlands
- Gebruik het woord "$word" nergens in je uitleg
- Schrijf als een woordenboekdefinitie
- Geef alleen de uitleg weer, niets anders''',

      'PL':
          '''Wyjaśnij znaczenie słowa "$word" bez używania samego słowa "$word".

Wymagania:
- Twoje wyjaśnienie musi mieć 10-30 słów
- Używaj prostego, codziennego słownictwa (${complexityDesc})
- Pisz TYLKO po polsku
- Nie używaj słowa "$word" nigdzie w swoim wyjaśnieniu
- Pisz jak definicja słownikowa
- Wypisz tylko wyjaśnienie, nic więcej''',

      'RU':
          '''Объясни значение слова "$word" не используя само слово "$word".

Требования:
- Твое объяснение должно содержать 10-30 слов
- Используй простую, повседневную лексику (${complexityDesc})
- Пиши ТОЛЬКО на русском языке
- Не используй слово "$word" нигде в своем объяснении
- Пиши как словарное определение
- Выведи только объяснение, ничего больше''',

      'CS':
          '''Vysvětli význam slova "$word" bez použití samotného slova "$word".

Požadavky:
- Tvé vysvětlení musí mít 10-30 slov
- Použij jednoduchou, každodenní slovní zásobu (${complexityDesc})
- Piš POUZE česky
- Nepoužívej slovo "$word" nikde ve svém vysvětlení
- Piš jako slovníková definice
- Vypiš pouze vysvětlení, nic jiného''',

      'SV':
          '''Förklara betydelsen av ordet "$word" utan att använda ordet "$word" självt.

Krav:
- Din förklaring måste vara 10-30 ord lång
- Använd enkelt, vardagligt ordförråd (${complexityDesc})
- Skriv ENDAST på svenska
- Använd inte ordet "$word" någonstans i din förklaring
- Skriv som en ordboksdefinition
- Skriv bara förklaringen, inget annat''',

      'DA':
          '''Forklar betydningen af ordet "$word" uden at bruge ordet "$word" selv.

Krav:
- Din forklaring skal være 10-30 ord lang
- Brug simpelt, dagligdags ordforråd (${complexityDesc})
- Skriv KUN på dansk
- Brug ikke ordet "$word" nogen steder i din forklaring
- Skriv som en ordbogsdefinition
- Skriv kun forklaringen, intet andet''',

      'NB':
          '''Forklar betydningen av ordet "$word" uten å bruke ordet "$word" selv.

Krav:
- Forklaringen din må være 10-30 ord lang
- Bruk enkelt, hverdagslig ordforråd (${complexityDesc})
- Skriv KUN på norsk
- Ikke bruk ordet "$word" noe sted i forklaringen din
- Skriv som en ordboksdefinisjon
- Skriv bare forklaringen, ingenting annet''',

      'TR':
          '''"$word" kelimesinin anlamını "$word" kelimesini kullanmadan açıkla.

Gereksinimler:
- Açıklaman 10-30 kelime uzunluğunda olmalı
- Basit, günlük kelime dağarcığı kullan (${complexityDesc})
- SADECE Türkçe yaz
- Açıklamanda "$word" kelimesini hiçbir yerde kullanma
- Sözlük tanımı gibi yaz
- Sadece açıklamayı yaz, başka bir şey yazma''',

      'AR':
          '''اشرح معنى كلمة "$word" دون استخدام كلمة "$word" نفسها.

المتطلبات:
- يجب أن يحتوي شرحك على 10-30 كلمة
- استخدم مفردات بسيطة ويومية (${complexityDesc})
- اكتب باللغة العربية فقط
- لا تستخدم كلمة "$word" في أي مكان في شرحك
- اكتب مثل تعريف القاموس
- اكتب الشرح فقط، لا شيء آخر''',

      'JA':
          '''「$word」という言葉を使わずに「$word」の意味を説明してください。

要件:
- 説明は10-30語でなければなりません
- 簡単な日常的な語彙を使用してください (${complexityDesc})
- 日本語のみで書いてください
- 説明のどこにも「$word」という言葉を使わないでください
- 辞書の定義のように書いてください
- 説明のみを出力し、他のものは何も出力しないでください''',

      'KO':
          '''"$word"라는 단어를 사용하지 않고 "$word"의 의미를 설명하세요.

요구사항:
- 설명은 10-30개의 단어여야 합니다
- 간단하고 일상적인 어휘를 사용하세요 (${complexityDesc})
- 한국어로만 작성하세요
- 설명 어디에도 "$word"라는 단어를 사용하지 마세요
- 사전 정의처럼 작성하세요
- 설명만 출력하고 다른 것은 출력하지 마세요''',

      'ZH':
          '''在不使用"$word"这个词的情况下解释"$word"的含义。

要求:
- 你的解释必须是10-30个字
- 使用简单的日常词汇 (${complexityDesc})
- 只用中文写
- 在你的解释中任何地方都不要使用"$word"这个词
- 像字典定义一样写
- 只输出解释，不要输出其他内容''',

      'EL':
          '''Εξήγησε τη σημασία της λέξης "$word" χωρίς να χρησιμοποιήσεις την ίδια τη λέξη "$word".

Απαιτήσεις:
- Η εξήγησή σου πρέπει να είναι 10-30 λέξεις
- Χρησιμοποίησε απλό, καθημερινό λεξιλόγιο (${complexityDesc})
- Γράψε ΜΟΝΟ στα ελληνικά
- Μην χρησιμοποιήσεις τη λέξη "$word" πουθενά στην εξήγησή σου
- Γράψε σαν ορισμό λεξικού
- Γράψε μόνο την εξήγηση, τίποτα άλλο''',

      'HU':
          '''Magyarázd el a "$word" szó jelentését anélkül, hogy magát a "$word" szót használnád.

Követelmények:
- A magyarázatodnak 10-30 szónak kell lennie
- Használj egyszerű, hétköznapi szókincset (${complexityDesc})
- Írj CSAK magyarul
- Ne használd a "$word" szót sehol a magyarázatodban
- Írj úgy, mint egy szótári definíció
- Csak a magyarázatot írd ki, semmi mást''',

      'RO':
          '''Explică semnificația cuvântului "$word" fără a folosi cuvântul "$word" însuși.

Cerințe:
- Explicația ta trebuie să aibă 10-30 de cuvinte
- Folosește vocabular simplu, cotidian (${complexityDesc})
- Scrie DOAR în română
- Nu folosi cuvântul "$word" nicăieri în explicația ta
- Scrie ca o definiție de dicționar
- Scrie doar explicația, nimic altceva''',

      'BG':
          '''Обясни значението на думата "$word" без да използваш самата дума "$word".

Изисквания:
- Обяснението ти трябва да съдържа 10-30 думи
- Използвай прост, ежедневен речник (${complexityDesc})
- Пиши САМО на български
- Не използвай думата "$word" никъде в обяснението си
- Пиши като речникова дефиниция
- Изведи само обяснението, нищо друго''',

      'UK':
          '''Поясни значення слова "$word" не використовуючи саме слово "$word".

Вимоги:
- Твоє пояснення повинно містити 10-30 слів
- Використовуй просту, повсякденну лексику (${complexityDesc})
- Пиши ТІЛЬКИ українською
- Не використовуй слово "$word" ніде у своєму поясненні
- Пиши як словникове визначення
- Виведи тільки пояснення, нічого більше''',

      'SK':
          '''Vysvetli význam slova "$word" bez použitia samotného slova "$word".

Požiadavky:
- Tvoje vysvetlenie musí mať 10-30 slov
- Použi jednoduchú, každodennú slovnú zásobu (${complexityDesc})
- Píš IBA po slovensky
- Nepoužívaj slovo "$word" nikde vo svojom vysvetlení
- Píš ako slovníková definícia
- Vypíš iba vysvetlenie, nič iné''',

      'SL':
          '''Razloži pomen besede "$word" brez uporabe same besede "$word".

Zahteve:
- Tvoja razlaga mora biti dolga 10-30 besed
- Uporabi preprost, vsakdanji besedni zaklad (${complexityDesc})
- Piši SAMO v slovenščini
- Ne uporabljaj besede "$word" nikjer v svoji razlagi
- Piši kot slovarska definicija
- Izpiši samo razlago, nič drugega''',

      'ET':
          '''Selgita sõna "$word" tähendust kasutamata sõna "$word" ennast.

Nõuded:
- Sinu selgitus peab olema 10-30 sõna pikkune
- Kasuta lihtsat, igapäevast sõnavara (${complexityDesc})
- Kirjuta AINULT eesti keeles
- Ära kasuta sõna "$word" mitte kusagil oma selgituses
- Kirjuta nagu sõnaraamatu definitsioon
- Väljasta ainult selgitus, mitte midagi muud''',

      'LT':
          '''Paaiškink žodžio "$word" reikšmę nenaudodamas paties žodžio "$word".

Reikalavimai:
- Tavo paaiškinimas turi būti 10-30 žodžių ilgio
- Naudok paprastą, kasdienį žodyną (${complexityDesc})
- Rašyk TIK lietuviškai
- Nenaudok žodžio "$word" niekur savo paaiškinime
- Rašyk kaip žodyno apibrėžimą
- Išvesk tik paaiškinimą, nieko daugiau''',

      'LV':
          '''Izskaidro vārda "$word" nozīmi, neizmantojot pašu vārdu "$word".

Prasības:
- Tavam izskaidrojumam jābūt 10-30 vārdu garam
- Izmanto vienkāršu, ikdienas vārdu krājumu (${complexityDesc})
- Raksti TIKAI latviski
- Neizmanto vārdu "$word" nekur savā izskaidrojumā
- Raksti kā vārdnīcas definīciju
- Izvadi tikai izskaidrojumu, neko citu''',

      'ID':
          '''Jelaskan arti kata "$word" tanpa menggunakan kata "$word" itu sendiri.

Persyaratan:
- Penjelasan Anda harus sepanjang 10-30 kata
- Gunakan kosakata sederhana sehari-hari (${complexityDesc})
- Tulis HANYA dalam bahasa Indonesia
- Jangan gunakan kata "$word" di mana pun dalam penjelasan Anda
- Tulis seperti definisi kamus
- Keluarkan hanya penjelasan, tidak ada yang lain''',
    };

    return prompts[langCode] ?? prompts['EN']!;
  }

  String _getComplexityDescription(String langCode) {
    final descriptions = {
      'EN': {
        1: 'A1 level - very basic words',
        2: 'A2 level - simple everyday words',
        3: 'B1 level - common words',
        4: 'B2 level - varied vocabulary',
        5: 'C1 level - advanced vocabulary',
        6: 'C2 level - sophisticated vocabulary',
      },
      'FI': {
        1: 'A1-taso - hyvin perussanoja',
        2: 'A2-taso - yksinkertaisia arkisanoja',
        3: 'B1-taso - tavallisia sanoja',
        4: 'B2-taso - monipuolista sanastoa',
        5: 'C1-taso - edistynyttä sanastoa',
        6: 'C2-taso - hienostunutta sanastoa',
      },
      'DE': {
        1: 'A1-Niveau - sehr einfache Wörter',
        2: 'A2-Niveau - einfache Alltagswörter',
        3: 'B1-Niveau - gebräuchliche Wörter',
        4: 'B2-Niveau - vielfältiger Wortschatz',
        5: 'C1-Niveau - fortgeschrittener Wortschatz',
        6: 'C2-Niveau - anspruchsvoller Wortschatz',
      },
      'ES': {
        1: 'Nivel A1 - palabras muy básicas',
        2: 'Nivel A2 - palabras cotidianas simples',
        3: 'Nivel B1 - palabras comunes',
        4: 'Nivel B2 - vocabulario variado',
        5: 'Nivel C1 - vocabulario avanzado',
        6: 'Nivel C2 - vocabulario sofisticado',
      },
      'FR': {
        1: 'Niveau A1 - mots très basiques',
        2: 'Niveau A2 - mots quotidiens simples',
        3: 'Niveau B1 - mots courants',
        4: 'Niveau B2 - vocabulaire varié',
        5: 'Niveau C1 - vocabulaire avancé',
        6: 'Niveau C2 - vocabulaire sophistiqué',
      },
      'RU': {
        1: 'Уровень A1 - очень простые слова',
        2: 'Уровень A2 - простые повседневные слова',
        3: 'Уровень B1 - обычные слова',
        4: 'Уровень B2 - разнообразная лексика',
        5: 'Уровень C1 - продвинутая лексика',
        6: 'Уровень C2 - изысканная лексика',
      },
      // Add more languages as needed, or fall back to English
    };

    final langDescriptions = descriptions[langCode] ?? descriptions['EN']!;
    return langDescriptions[complexity.level] ?? langDescriptions[3]!;
  }

  // =========================
  // VERIFICATION SYSTEM
  // =========================

  ResponseVerification _verifyExampleResponse(
    String response,
    String word,
    String langCode,
  ) {
    String corrected = response;
    bool isValid = true;
    List<String> issues = [];

    // 1. Check if response contains the target word
    if (!corrected.toLowerCase().contains(word.toLowerCase())) {
      issues.add('Missing target word');
      isValid = false;
    }

    // 2. Check for mixed languages (basic heuristic)
    if (_containsMultipleLanguages(corrected, langCode)) {
      issues.add('Contains multiple languages');
      corrected = _removeNonTargetLanguage(corrected, langCode);
    }

    // 3. Check length (should have 2-3 sentences)
    final sentences = _splitIntoSentences(corrected);
    if (sentences.length < 1) {
      issues.add('Too short');
      isValid = false;
    }
    if (sentences.length > 5) {
      issues.add('Too long');
      // Take first 3 sentences
      corrected = sentences.take(3).join(' ');
    }

    // 4. Remove any translations (text in parentheses or after dashes)
    corrected = _removeTranslations(corrected);

    // 5. Clean up formatting
    corrected = _cleanFormatting(corrected);

    return ResponseVerification(
      isValid: isValid && issues.isEmpty,
      correctedText: corrected,
      issues: issues,
    );
  }

  ResponseVerification _verifyExplanationResponse(
    String response,
    String word,
    String langCode,
  ) {
    String corrected = response;
    bool isValid = true;
    List<String> issues = [];

    // 1. Check if explanation contains the word itself (should not!)
    if (_containsWord(corrected, word)) {
      issues.add('Contains forbidden word');
      // Try to remove the word
      corrected = _removeForbiddenWord(corrected, word);
    }

    // 2. Check for mixed languages
    if (_containsMultipleLanguages(corrected, langCode)) {
      issues.add('Contains multiple languages');
      corrected = _removeNonTargetLanguage(corrected, langCode);
    }

    // 3. Check length (should be 10-30 words)
    final wordCount = corrected.split(RegExp(r'\s+')).length;
    if (wordCount < 5) {
      issues.add('Too short');
      isValid = false;
    }
    if (wordCount > 50) {
      issues.add('Too long');
      // Truncate to first sentence
      final sentences = _splitIntoSentences(corrected);
      corrected = sentences.isNotEmpty ? sentences.first : corrected;
    }

    // 4. Remove any translations
    corrected = _removeTranslations(corrected);

    // 5. Clean up formatting
    corrected = _cleanFormatting(corrected);

    return ResponseVerification(
      isValid: isValid && issues.isEmpty,
      correctedText: corrected,
      issues: issues,
    );
  }

  // =========================
  // HELPER VERIFICATION FUNCTIONS
  // =========================

  bool _containsWord(String text, String word) {
    // Check if text contains the word (case-insensitive, whole word)
    final pattern = RegExp(
      r'\b' + RegExp.escape(word) + r'\b',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  String _removeForbiddenWord(String text, String word) {
    // Remove the forbidden word and clean up
    final pattern = RegExp(
      r'\b' + RegExp.escape(word) + r'\b',
      caseSensitive: false,
    );
    return text
        .replaceAll(pattern, '___')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsMultipleLanguages(String text, String targetLang) {
    // Basic heuristic: check for mixed scripts
    // This is a simplified check - can be enhanced

    final scripts = <String>{};

    for (final char in text.runes) {
      if (char >= 0x0400 && char <= 0x04FF)
        scripts.add('cyrillic');
      else if (char >= 0x0600 && char <= 0x06FF)
        scripts.add('arabic');
      else if (char >= 0x4E00 && char <= 0x9FFF)
        scripts.add('cjk');
      else if (char >= 0x3040 && char <= 0x309F)
        scripts.add('hiragana');
      else if (char >= 0x30A0 && char <= 0x30FF)
        scripts.add('katakana');
      else if (char >= 0x0370 && char <= 0x03FF)
        scripts.add('greek');
      else if ((char >= 0x0041 && char <= 0x007A) ||
          (char >= 0x00C0 && char <= 0x024F)) {
        scripts.add('latin');
      }
    }

    // If more than one script, likely multiple languages
    return scripts.length > 1;
  }

  String _removeNonTargetLanguage(String text, String langCode) {
    // This is a simplified approach - remove non-target script text
    // For production, you might want a more sophisticated approach

    final targetScript = _getExpectedScript(langCode);
    final buffer = StringBuffer();

    for (final char in text.runes) {
      final charScript = _getCharScript(char);
      if (charScript == targetScript || charScript == 'common') {
        buffer.writeCharCode(char);
      }
    }

    return buffer.toString().trim();
  }

  String _getExpectedScript(String langCode) {
    const scriptMap = {
      'RU': 'cyrillic',
      'UK': 'cyrillic',
      'BG': 'cyrillic',
      'AR': 'arabic',
      'JA': 'cjk',
      'KO': 'cjk',
      'ZH': 'cjk',
      'EL': 'greek',
    };
    return scriptMap[langCode] ?? 'latin';
  }

  String _getCharScript(int charCode) {
    if (charCode >= 0x0400 && charCode <= 0x04FF) return 'cyrillic';
    if (charCode >= 0x0600 && charCode <= 0x06FF) return 'arabic';
    if (charCode >= 0x4E00 && charCode <= 0x9FFF) return 'cjk';
    if (charCode >= 0x3040 && charCode <= 0x30FF) return 'cjk';
    if (charCode >= 0x0370 && charCode <= 0x03FF) return 'greek';
    if ((charCode >= 0x0041 && charCode <= 0x007A) ||
        (charCode >= 0x00C0 && charCode <= 0x024F))
      return 'latin';
    return 'common'; // Numbers, punctuation, etc.
  }

  List<String> _splitIntoSentences(String text) {
    // Split by common sentence terminators
    return text
        .split(RegExp(r'[.!?。！？]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _removeTranslations(String text) {
    // Remove text in parentheses (often translations)
    return text.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
  }

  String _cleanFormatting(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single
        .replaceAll(RegExp(r'\n+'), ' ') // Newlines to space
        .replaceAll(RegExp(r'^[•\-*]\s*'), '') // Remove bullet points
        .replaceAll(RegExp(r'^\d+\.\s*'), '') // Remove numbering
        .trim();
  }

  // =========================
  // FALLBACK RESPONSES
  // =========================

  String _getFallbackExample(String word, String langCode) {
    // Simple fallback when AI completely fails
    final fallbacks = {
      'EN': 'I use $word every day.',
      'FI': 'Käytän sanaa $word joka päivä.',
      'DE': 'Ich benutze $word jeden Tag.',
      'ES': 'Uso $word todos los días.',
      'FR': 'J\'utilise $word tous les jours.',
      'RU': 'Я использую $word каждый день.',
    };
    return fallbacks[langCode] ?? 'Example with $word.';
  }

  String _getFallbackExplanation(String word, String langCode) {
    // Simple fallback
    final fallbacks = {
      'EN': 'A common term in everyday language.',
      'FI': 'Yleinen termi arkikielessä.',
      'DE': 'Ein gebräuchlicher Begriff in der Alltagssprache.',
      'ES': 'Un término común en el lenguaje cotidiano.',
      'FR': 'Un terme courant dans le langage quotidien.',
      'RU': 'Распространенный термин в повседневном языке.',
    };
    return fallbacks[langCode] ?? 'A commonly used term.';
  }

  // =========================
  // CORE AI CALLS
  // =========================

  Future<String> _callAI(String prompt) async {
    switch (provider) {
      case AIProvider.huggingface:
        return _callHuggingFace(prompt);
      case AIProvider.gemini:
        return _callGemini(prompt);
    }
  }

  Future<String> _callHuggingFace(String prompt) async {
    final response = await http.post(
      Uri.parse('$hfBaseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': activeModel,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 200,
        'temperature': 0.7,
        'top_p': 0.9,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'HuggingFace API error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final message = data['choices'][0]['message'];
    return message['content'] as String;
  }

  Future<String> _callGemini(String prompt) async {
    final response = await http.post(
      Uri.parse(geminiBaseUrl),
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 200},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  String _cleanResponse(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'^```.*\n'), '')
        .replaceAll(RegExp(r'\n```$'), '')
        .replaceAll(
          RegExp(r"^(Here's|Here is|Output:|Result:)\s*", caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'^"|"$'), '')
        .trim();
  }

  String _getLanguageName(String code) {
    const names = {
      'AR': 'Arabic',
      'BG': 'Bulgarian',
      'CS': 'Czech',
      'DA': 'Danish',
      'DE': 'German',
      'EL': 'Greek',
      'EN': 'English',
      'ES': 'Spanish',
      'ET': 'Estonian',
      'FI': 'Finnish',
      'FR': 'French',
      'HU': 'Hungarian',
      'ID': 'Indonesian',
      'IT': 'Italian',
      'JA': 'Japanese',
      'KO': 'Korean',
      'LT': 'Lithuanian',
      'LV': 'Latvian',
      'NB': 'Norwegian',
      'NL': 'Dutch',
      'PL': 'Polish',
      'PT': 'Portuguese',
      'RO': 'Romanian',
      'RU': 'Russian',
      'SK': 'Slovak',
      'SL': 'Slovenian',
      'SV': 'Swedish',
      'TR': 'Turkish',
      'UK': 'Ukrainian',
      'ZH': 'Chinese',
    };
    return names[code] ?? 'English';
  }
}

// =========================
// SUPPORTING CLASSES
// =========================

class ResponseVerification {
  final bool isValid;
  final String correctedText;
  final List<String> issues;

  ResponseVerification({
    required this.isValid,
    required this.correctedText,
    required this.issues,
  });
}

class HFModel {
  final String name;
  final String id;
  final String description;
  final bool recommended;

  const HFModel({
    required this.name,
    required this.id,
    required this.description,
    this.recommended = false,
  });
}
