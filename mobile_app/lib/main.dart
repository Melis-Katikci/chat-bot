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
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // ---------------------------------------------------------------------------
  // CHAT VE FORM DURUMLARI
  // ---------------------------------------------------------------------------

  bool _isChatOpen = false;
  bool _showSupportForm = false;
  bool _isHovered = false;

  // Botun hangi cevabı beklediğini tutar.
  //
  // null      -> Normal kullanıcı sorusu
  // 'answer'  -> "Yanıtım yeterli oldu mu?" cevabı
  // 'another' -> "Başka sorunuz var mı?" cevabı
  // 'support' -> "Destek / Şikayet Formu ister misiniz?" cevabı
  String? _waitingFor;

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

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    _messageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _supportMessageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // MESAİ SAATİ KONTROLÜ (Hafta içi 09:00 - 18:00)
  // ---------------------------------------------------------------------------

  bool _isWorkingHours() {
    final now = DateTime.now();

    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return false;
    }

    if (now.hour < 9 || now.hour >= 18) {
      return false;
    }

    return true;
  }

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
    ];

    for (final pattern in patterns) {
      cleanedResponse = cleanedResponse.replaceAll(pattern, '');
    }

    return cleanedResponse.trim();
  }

  // ---------------------------------------------------------------------------
  // OTOMATİK AŞAĞI KAYDIRMA
  // ---------------------------------------------------------------------------

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // API'DEN BOT CEVABI ALMA
  // ---------------------------------------------------------------------------

 Future<void> _fetchBotAnswer(String userText) async {
    try {
      final response = await ApiService.sendMessage(userText);

      if (!mounted) return;

      final cleanedResponse = _cleanApiResponse(response);

      setState(() {
        // API'den gelen asıl cevabı ekrana basıyoruz
        _messages.add({'sender': 'bot', 'text': cleanedResponse});

        // EĞER PYTHON BOT "ÜZGÜNÜM" VEYA "MERHABA" DEDİYSE FARKLI DAVRAN:
        if (cleanedResponse.contains('Üzgünüm, sorduğunuz soruyla ilgili')) {
          
          if (!_isWorkingHours()) {
            _messages.add({
              'sender': 'bot',
              'text': 'Şu anda mesai saatleri dışındayız. Destek / Şikayet Formu doldurmak ister misiniz? (Evet / Hayır)',
            });
            _waitingFor = 'support';
          } else {
            _messages.add({
              'sender': 'bot',
              'text': 'Dilerseniz Müşteri Temsilcimize 0850 XXX XX XX numarasından ulaşabilirsiniz. Başka bir sorunuz var mı? (Evet / Hayır)',
            });
            _waitingFor = 'another';
          }

        } 
        else if (cleanedResponse.contains('Merhaba! Size AboneSepeti ile ilgili')) {
          // Eğer karşılama mesajı döndüyse ekstra bir şey sormaya gerek yok
          _waitingFor = null;
        } 
        else {
          // NORMAL İŞLEYİŞ: Bot mantıklı bir cevap bulduysa
          _messages.add({
            'sender': 'bot',
            'text': 'Yanıt yeterli oldu mu? (Evet / Hayır)',
          });
          _waitingFor = 'answer';
        }
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': 'Üzgünüm, şu anda yanıt oluştururken bir sorun oluştu.',
        });
      });
      _scrollToBottom();
    }
  }

  // ---------------------------------------------------------------------------
  // MESAJ GÖNDERME
  // ---------------------------------------------------------------------------

  void _handleSendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    final lowerText = text.toLowerCase();

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _messageController.clear();
    });

    _focusNode.requestFocus();
    _scrollToBottom();

    // 1. "YANITIM YETERLİ OLDU MU?" BEKLENİYORSA
    if (_waitingFor == 'answer') {
      if (lowerText.contains('evet')) {
        setState(() {
          // Başka soru sormak yerine teşekkür edip görüşmeyi sonlandırıyoruz
          _messages.add({
            'sender': 'bot', 
            'text': 'Size yardımcı olabildiğime çok sevindim! Bizi tercih ettiğiniz için teşekkür eder, iyi günler dileriz. 😊'
          });
          // Bekleme durumunu sıfırlayarak botu başlangıç moduna döndürüyoruz
          _waitingFor = null;
        });
        _scrollToBottom();
        return;
      } else if (lowerText.contains('hayır') || lowerText.contains('hayir')) {  if (!_isWorkingHours()) {
          setState(() {
            _messages.add({
              'sender': 'bot',
              'text':
                  'Şu anda mesai saatleri dışındayız. Destek / Şikayet Formu doldurmak ister misiniz? (Evet / Hayır)',
            });
            _waitingFor = 'support';
          });
        } else {
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
        _scrollToBottom();
        return;
      } else {
        _waitingFor = null;
        await _fetchBotAnswer(text);
        return;
      }
    }

    // 2. "BAŞKA SORUNUZ VAR MI?" BEKLENİYORSA
    if (_waitingFor == 'another') {
      if (lowerText.contains('evet')) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': 'Tabii, sorunuzu yazabilirsiniz.',
          });
          _waitingFor = null;
        });
        _scrollToBottom();
        return;
      } else if (lowerText.contains('hayır') || lowerText.contains('hayir')) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': 'İyi günler, görüşmek üzere! 😊',
          });
          _waitingFor = null;
        });
        _scrollToBottom();
        return;
      } else {
        _waitingFor = null;
        await _fetchBotAnswer(text);
        return;
      }
    }

    // 3. "DESTEK / ŞİKAYET FORMU İSTER MİSİNİZ?" BEKLENİYORSA
    if (_waitingFor == 'support') {
      if (lowerText.contains('evet')) {
        setState(() {
          _showSupportForm = true;
          _waitingFor = null;
        });
        return;
      } else if (lowerText.contains('hayır') || lowerText.contains('hayir')) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text':
                'Mesai saatlerimiz hafta içi 09:00 - 18:00 arasındadır. '
                'Dilerseniz bu saatler içerisinde 0850 XXX XX XX numaramızdan bizi arayabilirsiniz.',
          });
          _waitingFor = null;
        });
        _scrollToBottom();
        return;
      } else {
        _waitingFor = null;
        await _fetchBotAnswer(text);
        return;
      }
    }

    // 4. NORMAL KULLANICI SORUSU (API İSTEĞİ)
    await _fetchBotAnswer(text);
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
      _scrollToBottom();
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
                          gradient: LinearGradient(
                            colors: [Color(0xFF0056b3), Color(0xFF007BFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.elasticOut,
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Transform.translate(
                                        offset: const Offset(-1.0, 0.0),
                                        child: Transform.scale(
                                          scale: 1.35,
                                          child: Image.asset(
                                            'assets/images/bot_icon.png',
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AboneSepeti Destek',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Row(
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox(width: 8, height: 8),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Çevrimiçi',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
      floatingActionButton: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered && !_isChatOpen ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.15),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isChatOpen = !_isChatOpen;
                      _isHovered = false;
                    });
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    child: _isChatOpen
                        ? AnimatedContainer(
                            key: const ValueKey('close_icon'),
                            width: 72,
                            height: 72,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isHovered
                                  ? const Color(0xFF007BFF)
                                  : Colors.white,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.close,
                                color: _isHovered
                                    ? Colors.white
                                    : const Color(0xFF007BFF),
                                size: 32,
                              ),
                            ),
                          )
                        : Container(
                            key: const ValueKey('bot_icon'),
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: ClipOval(
                              child: Transform.translate(
                                offset: const Offset(-2.0, 0.0),
                                child: Transform.scale(
                                  scale: 1.35,
                                  child: Image.asset(
                                    'assets/images/bot_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
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
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['sender'] == 'user';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: isUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isUser) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/bot_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.70,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color(0xFF007BFF)
                              : const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isUser
                                ? const Radius.circular(16)
                                : const Radius.circular(4),
                            bottomRight: isUser
                                ? const Radius.circular(4)
                                : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['text']!,
                              style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87,
                                fontSize: 14.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // MESAJ YAZMA ALANI
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF007BFF),
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    splashColor: Colors.white.withValues(alpha: 0.3),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    onTap: _handleSendMessage,
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Destek / Şikayet Formu',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Şu an mesai saatleri dışındayız. Lütfen bilgilerinizi bırakın, size en kısa sürede ulaşalım.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildTextField(_nameController, 'Ad Soyad', Icons.person_outline),
          const SizedBox(height: 12),
          _buildTextField(_emailController, 'E-Posta', Icons.email_outlined),
          const SizedBox(height: 12),
          _buildTextField(_phoneController, 'Telefon', Icons.phone_outlined),
          const SizedBox(height: 12),
          _buildTextField(
            _subjectController,
            'Konu / Başlık',
            Icons.subject_outlined,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _supportMessageController,
            'Mesajınız',
            Icons.message_outlined,
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _submitSupportForm,
            child: const Text(
              'Gönder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showSupportForm = false;
              });
            },
            icon: const Icon(Icons.arrow_back, size: 18, color: Colors.grey),
            label: const Text(
              'Sohbete Dön',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: Colors.grey.shade400, size: 22)
            : null,
        alignLabelWithHint: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF007BFF), width: 2),
        ),
      ),
    );
  }
}
