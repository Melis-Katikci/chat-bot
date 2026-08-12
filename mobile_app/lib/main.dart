import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AboneSepeti Destek',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ---------------------------------------------------------------------------
  // CHAT VE FORM DURUMLARI
  // ---------------------------------------------------------------------------

  bool _isChatOpen = false;
  bool _showSupportForm = false;

  // Botun hangi cevabı beklediğini tutar.
  //
  // null      -> Normal kullanıcı sorusu
  // 'answer'  -> "Yanıtım yeterli oldu mu?" cevabı
  // 'another' -> "Başka sorunuz var mı?" cevabı
  // 'support' -> "Destek / Şikayet Formu ister misiniz?" cevabı
  String? _waitingFor;

  // ---------------------------------------------------------------------------
  // MESAİ SAATİ KONTROLÜ (Hafta içi 09:00 - 18:00)
  // ---------------------------------------------------------------------------

  bool _isWorkingHours() {
    final now = DateTime.now();

    // Cumartesi veya Pazar ise mesai dışı
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return false;
    }

    // Saat 09:00 öncesi veya 18:00 sonrası ise mesai dışı
    if (now.hour < 7 || now.hour >= 8) {
      return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // CHAT KONTROLLERİ
  // ---------------------------------------------------------------------------

  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, String>> _messages = [
    {
      'sender': 'bot',
      'text':
          'Merhaba! AboneSepeti Canlı Destek sistemine hoş geldiniz. Size nasıl yardımcı olabilirim?',
    },
  ];

  // ---------------------------------------------------------------------------
  // DESTEK / ŞİKAYET FORMU KONTROLLERİ
  // ---------------------------------------------------------------------------

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectController = TextEditingController();
  final _supportMessageController = TextEditingController();

  // ---------------------------------------------------------------------------
  // API CEVABINI TEMİZLEME
  // ---------------------------------------------------------------------------

  String _cleanApiResponse(String response) {
    String cleanedResponse = response.trim();

    final patterns = [
      'Bu yanıt yeterli oldu mu? (Evet/Hayır)',
      'Bu yanıt yeterli oldu mu? (Evet / Hayır)',
      'Yanıt yeterli oldu mu? (Evet/Hayır)',
      'Yanıt yeterli oldu mu? (Evet / Hayır)',
      'Yanıt yeterli oldu mu? (Evet/Hayır)',
      'Yanıt yeterli oldu mu? (Evet / Hayır)',
    ];

    for (final pattern in patterns) {
      cleanedResponse = cleanedResponse.replaceAll(pattern, '');
    }

    return cleanedResponse.trim();
  }

  // ---------------------------------------------------------------------------
  // MESAJ GÖNDERME
  // ---------------------------------------------------------------------------

  void _handleSendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    final lowerText = text.toLowerCase();

    // Kullanıcı mesajını ekrana ekle
    setState(() {
      _messages.add({'sender': 'user', 'text': text});

      _messageController.clear();
    });

    // ========================================================================
    // 1. "YANITIM YETERLİ OLDU MU?" SORUSUNUN CEVABI
    // ========================================================================

    if (_waitingFor == 'answer') {
      // ----------------------------------------------------------------------
      // Kullanıcı EVET dediyse
      // ----------------------------------------------------------------------

      if (lowerText.contains('evet')) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': 'Başka sorunuz var mı?'});

          _waitingFor = 'another';
        });
      }
      // ----------------------------------------------------------------------
      // Kullanıcı HAYIR dediyse
      // ----------------------------------------------------------------------
      else if (lowerText.contains('hayır') || lowerText.contains('hayir')) {
        // MESAİ SAATİ DIŞINDAYSA -> Doğrudan Şikayet Formu Sor
        if (!_isWorkingHours()) {
          setState(() {
            _messages.add({
              'sender': 'bot',
              'text':
                  'Şu anda mesai saatleri dışındayız. Destek / Şikayet Formu doldurmak ister misiniz? (Evet / Hayır)',
            });

            _waitingFor = 'support';
          });
        }
        // MESAİ SAATİ İÇİNDEYSE -> Müşteri Hizmetleri Numarasını Göster
        else {
          setState(() {
            _messages.add({
              'sender': 'bot',
              'text':
                  'Müşteri hizmetlerimizi arayabilirsiniz.\n\n'
                  'Telefon numaramız: 0850 XXX XX XX',
            });

            _waitingFor = null;
          });
        }
      }

      return;
    }

    // ========================================================================
    // 2. "BAŞKA SORUNUZ VAR MI?" SORUSUNUN CEVABI
    // ========================================================================

    if (_waitingFor == 'another') {
      // ----------------------------------------------------------------------
      // Kullanıcı EVET dediyse -> Yeni soru sorabilir
      // ----------------------------------------------------------------------

      if (lowerText.contains('evet')) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': 'Tabii, sorunuzu yazabilirsiniz.',
          });

          _waitingFor = null;
        });
      }
      // ----------------------------------------------------------------------
      // Kullanıcı HAYIR dediyse -> Sohbeti sonlandır
      // ----------------------------------------------------------------------
      else if (lowerText.contains('hayır') || lowerText.contains('hayir')) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': 'İyi günler, görüşmek üzere! 😊',
          });

          _waitingFor = null;
        });
      }

      return;
    }

    // ========================================================================
    // 3. "DESTEK / ŞİKAYET FORMU İSTER MİSİNİZ?" SORUSUNUN CEVABI
    // ========================================================================

    if (_waitingFor == 'support') {
      // ----------------------------------------------------------------------
      // Kullanıcı EVET dediyse FORMU AÇ
      // ----------------------------------------------------------------------

      if (lowerText.contains('evet')) {
        setState(() {
          _showSupportForm = true;
          _waitingFor = null;
        });
      }
      // ----------------------------------------------------------------------
      // Kullanıcı HAYIR dediyse TELEFON NUMARASI + MESAİ SAATİ
      // ----------------------------------------------------------------------
      else if (lowerText.contains('hayır') || lowerText.contains('hayir')) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text':
                'Mesai saatlerimiz hafta içi 09:00 - 18:00 arasındadır. '
                'Dilerseniz bu saatler içerisinde 0850 XXX XX XX numaramızdan bizi arayabilirsiniz.',
          });

          _waitingFor = null;
        });
      }

      return;
    }

    // ========================================================================
    // 4. NORMAL KULLANICI SORUSU (API İSTEĞİ)
    // ========================================================================

    try {
      final response = await ApiService.sendMessage(text);

      if (!mounted) return;

      final cleanedResponse = _cleanApiResponse(response);

      setState(() {
        // API cevabını göster
        _messages.add({'sender': 'bot', 'text': cleanedResponse});

        // Yanıt yeterli mi sorusunu ekle
        _messages.add({
          'sender': 'bot',
          'text': 'Yanıt yeterli oldu mu? (Evet / Hayır)',
        });

        _waitingFor = 'answer';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': 'Üzgünüm, şu anda yanıt oluştururken bir sorun oluştu.',
        });
      });
    }
  }

  // ---------------------------------------------------------------------------
  // DESTEK FORMUNU GÖNDERME
  // ---------------------------------------------------------------------------

  void _submitSupportForm() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final subject = _subjectController.text.trim();
    final message = _supportMessageController.text.trim();

    if (name.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir Ad Soyad giriniz.'),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final phoneRegex = RegExp(r'^[0-9]{10,11}$');

    if (!phoneRegex.hasMatch(cleanPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lütfen 10 veya 11 haneli geçerli bir telefon numarası giriniz.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    final success = await ApiService.sendSupportForm(
      name: name,
      email: email,
      phone: phone,
      subject: subject,
      message: message,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _showSupportForm = false;

        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _subjectController.clear();
        _supportMessageController.clear();

        _messages.add({
          'sender': 'bot',
          'text':
              'Formunuz başarıyla gönderildi. En kısa sürede size dönüş sağlanacaktır.',
        });

        _messages.add({
          'sender': 'bot',
          'text': 'Başka yardımcı olabileceğim bir konu var mı?',
        });

        _waitingFor = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sunucuya bağlanırken hata oluştu.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ANA ARAYÜZ
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          if (_isChatOpen)
            Positioned(
              bottom: 90,
              right: 16,
              width: MediaQuery.of(context).size.width * 0.88,
              height: 520,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      // CHAT HEADER
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF007BFF),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.support_agent, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'AboneSepeti Destek',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isChatOpen = false;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                      // CHAT VEYA FORM
                      Expanded(
                        child: _showSupportForm
                            ? _buildSupportFormUI()
                            : _buildChatUI(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // SAĞ ALT CHAT BUTONU
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF007BFF),
        elevation: 6,
        onPressed: () {
          setState(() {
            _isChatOpen = !_isChatOpen;
          });
        },
        child: Icon(
          _isChatOpen ? Icons.close : Icons.chat_bubble,
          color: Colors.white,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CHAT ARAYÜZÜ
  // ---------------------------------------------------------------------------

  Widget _buildChatUI() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['sender'] == 'user';

              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF007BFF)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    msg['text']!,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // MESAJ YAZMA ALANI
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Mesajınızı yazın...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onSubmitted: (_) => _handleSendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF007BFF)),
                onPressed: _handleSendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DESTEK / ŞİKAYET FORMU
  // ---------------------------------------------------------------------------

  Widget _buildSupportFormUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Destek / Şikayet Formu',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          const SizedBox(height: 4),

          Text(
            'Mesai saatleri dışındayız. Bilgilerinizi bırakın, size ulaşalım.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),

          const SizedBox(height: 10),

          _buildTextField(_nameController, 'Ad Soyad'),

          _buildTextField(_emailController, 'E-Posta'),

          _buildTextField(_phoneController, 'Telefon'),

          _buildTextField(_subjectController, 'Konu / Başlık'),

          _buildTextField(_supportMessageController, 'Mesajınız', maxLines: 3),

          const SizedBox(height: 10),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _submitSupportForm,
            child: const Text('Gönder'),
          ),

          TextButton(
            onPressed: () {
              setState(() {
                _showSupportForm = false;
              });
            },
            child: const Text('Sohbete Dön', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEXT FIELD
  // ---------------------------------------------------------------------------

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
