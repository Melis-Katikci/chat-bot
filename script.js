// 1. Animasyonlu Pencere Açma / Kapama Fonksiyonu
function toggleChat() {
    const widget = document.getElementById('chat-widget');
    const fabBtn = document.getElementById('fab-button');
    const fabIcon = document.getElementById('fab-icon');
    const fabClose = document.getElementById('fab-close');

    const isOpen = widget.classList.contains('show');

    if (isOpen) {
        widget.classList.remove('show');
        fabBtn.classList.remove('active');
        fabIcon.style.display = 'block';
        fabClose.style.display = 'none';
    } else {
        widget.classList.add('show');
        fabBtn.classList.add('active');
        fabIcon.style.display = 'none';
        fabClose.style.display = 'block';
    }
}

// 2. Mesai Saati Kontrolü (Hafta içi 09:00 - 18:00)
function isWorkingHours() {
    const now = new Date();
    const day = now.getDay(); // 0: Pazar, 6: Cumartesi
    const hour = now.getHours();

    if (day === 0 || day === 6) return false;
    if (hour < 9 || hour >= 18) return false;

    return true;
}

let waitingForConsent = false;

// Enter tuşu ile gönderme desteği
function handleKeyPress(event) {
    if (event.key === 'Enter') {
        sendMessage();
    }
}

// 3. Mesaj Gönderme ve Arayüze Balon Ekleme Mantığı
async function sendMessage() {
    const inputField = document.getElementById('user-input');
    const chatBox = document.getElementById('chat-box');
    const userMsg = inputField.value.trim();

    if (!userMsg) return;

    // Kullanıcı Mesajını Ekle
    chatBox.innerHTML += `
        <div class="message user-message">
            <div class="msg-bubble">${userMsg}</div>
        </div>
    `;
    inputField.value = '';
    chatBox.scrollTop = chatBox.scrollHeight;

    // Kullanıcı yönlendirmeye EVET dedi mi?
    if (waitingForConsent) {
        if (userMsg.toLowerCase().includes('evet')) {
            document.getElementById('chat-body').classList.add('hidden-view');
            document.getElementById('support-form-container').classList.remove('hidden-view');
        } else {
            addBotMessage("Anlaşıldı. Başka bir sorunuz olursa yazabilirsiniz.");
            waitingForConsent = false;
        }
        return;
    }

    // Mesai dışındaysa forma yönlendir
    if (!isWorkingHours()) {
        addBotMessage("Şu anda mesai saatleri dışındayız. Destek talebinde bulunmak ister misiniz? (Evet / Hayır)");
        waitingForConsent = true;
        return;
    }
    // Mesajdaki noktalama işaretlerini ve boşlukları silip sadece harfleri alıyoruz (örn: "selam!" -> "selam")
    const cleanedMsg = userMsg.toLowerCase().replace(/[^a-zçğıöşü]/g, ''); 
    const greetings = ['merhaba', 'merhabalar', 'meraba', 'merab', 'selam', 'selamlar', 'slm', 'mrb'];
    
    if (greetings.includes(cleanedMsg)) {
        addBotMessage("Merhabalar. Dilerseniz Yardımcı olmamı istediğiniz konuyu belirtin");
        return; // return diyerek kodun aşağıya (backend'e) gitmesini engelliyoruz
        }

    
   // Spring Boot Backend'e İstek At
    try {
        const response = await fetch('http://localhost:9000/api/chat/ask', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ question: userMsg, userId: 1 })
        });

        if (!response.ok) throw new Error("Sunucu hatası");

        const data = await response.json();
        addBotMessage(data.answer);

    } catch (error) {
        console.error("Hata:", error);
        addBotMessage("Üzgünüm, sunucuya erişirken bir hata oluştu.");
    }
}

// Bot mesajını arayüze ekleyen yardımcı fonksiyon
function addBotMessage(text) {
    const chatBox = document.getElementById('chat-box');
    chatBox.innerHTML += `
        <div class="message bot-message">
            <div class="avatar-wrapper">
                <img src="mobile_app/assets/images/bot_icon.png" alt="Bot" class="msg-avatar">
            </div>
            <div class="msg-bubble">${text}</div>
        </div>
    `;
    chatBox.scrollTop = chatBox.scrollHeight;
}

function returnToChat() {
    document.getElementById('support-form-container').classList.add('hidden-view');
    document.getElementById('chat-body').classList.remove('hidden-view');
}

// 4. Form Doğrulama ve Backend'e Gönderme
function handleFormSubmit(event) {
    event.preventDefault();

    const name = document.getElementById('name').value.trim();
    const email = document.getElementById('email').value.trim();
    const phone = document.getElementById('phone').value.trim();
    const subject = document.getElementById('subject').value.trim();
    const message = document.getElementById('message').value.trim();

    if (name.length < 3) {
        alert("Lütfen geçerli bir Ad Soyad giriniz.");
        return;
    }

    const phoneRegex = /^[0-9]{10,11}$/;
    if (!phoneRegex.test(phone.replace(/\s+/g, ''))) {
        alert("Lütfen 10 veya 11 haneli geçerli bir telefon numarası giriniz.");
        return;
    }

    const formData = { name, email, phone, subject, message };

    fetch('http://localhost:9000/api/support', { 
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
    })
    .then(async (res) => {
        const data = await res.json().catch(() => ({}));
        const feedback = document.getElementById('formFeedback');
        if (res.ok || data.success) {
            feedback.style.color = "#28a745";
            feedback.innerText = "Talebiniz başarıyla iletildi!";
            document.getElementById('supportForm').reset();
            
            // Başarılı olunca birkaç saniye sonra sohbete geri dön
            setTimeout(() => {
                returnToChat();
                addBotMessage("Formunuz başarıyla gönderildi. Başka yardımcı olabileceğim bir konu var mı?");
                feedback.innerText = "";
                waitingForConsent = false;
            }, 2000);
            
        } else {
            feedback.style.color = "#dc3545";
            feedback.innerText = "Hata: " + (data.message || "Gönderilemedi.");
        }
    })
    .catch((err) => {
        console.error("Form Gönderme Hatası:", err);
        document.getElementById('formFeedback').style.color = "#dc3545";
        document.getElementById('formFeedback').innerText = "Sunucuya bağlanırken hata oluştu.";
    });
}