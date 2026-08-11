// 1. Pencere Açma / Kapama Fonksiyonu
function toggleChat() {
    const widget = document.getElementById('chat-widget');
    widget.classList.toggle('hidden');
}

// 2. Mesai Saati Kontrolü (Hafta içi 09:00 - 18:00 dışı mesai dışıdır)
function isWorkingHours() {
    const now = new Date();
    const day = now.getDay(); // 0: Pazar, 6: Cumartesi
    const hour = now.getHours();

    if (day === 0 || day === 6) return false;
    if (hour < 8 || hour >= 9) return false;

    return true;
}

let waitingForConsent = false;

// 3. Mesaj Gönderme ve Spring Boot Bağlantı Mantığı 
async function sendMessage() {
    const inputField = document.getElementById('user-input');
    const chatBox = document.getElementById('chat-box');
    const userMsg = inputField.value.trim();

    if (!userMsg) return;

    chatBox.innerHTML += `<div><strong>Siz:</strong> ${userMsg}</div>`;
    inputField.value = '';

    // Kullanıcı yönlendirmeye EVET dedi mi?
    if (waitingForConsent) {
        if (userMsg.toLowerCase().includes('evet')) {
            document.getElementById('chat-body').classList.add('hidden');
            document.getElementById('support-form-container').classList.remove('hidden');
        } else {
            chatBox.innerHTML += `<div><strong>Bot:</strong> Anlaşıldı. Başka bir sorunuz olursa yazabilirsiniz.</div>`;
            waitingForConsent = false;
        }
        chatBox.scrollTop = chatBox.scrollHeight;
        return;
    }

    // Mesai dışındaysa forma yönlendir
    if (!isWorkingHours()) {
        chatBox.innerHTML += `<div><strong>Bot:</strong> Şu anda mesai saatleri dışındayız. Destek talebinde bulunmak ister misiniz? (Evet / Hayır)</div>`;
        waitingForConsent = true;
        chatBox.scrollTop = chatBox.scrollHeight;
        return;
    }

    // --- MESAİ SAATİ İÇİNDEYSE: Spring Boot Backend'e İstek At ---
    try {
        const response = await fetch('http://localhost:8080/api/chat/ask', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                question: userMsg,
                userId: 1
            })
        });

        if (!response.ok) {
            throw new Error("Sunucu hatası: " + response.status);
        }

        const data = await response.json();
        
        // Spring Boot'tan gelen cevabı ekrana yazdır
        chatBox.innerHTML += `<div><strong>Bot:</strong> ${data.answer}</div>`;

    } catch (error) {
        console.error("Hata:", error);
        chatBox.innerHTML += `<div><strong>Bot:</strong> Üzgünüm, sunucuya erişirken bir hata oluştu.</div>`;
    }

    chatBox.scrollTop = chatBox.scrollHeight;
}

// 4. Form Doğrulama ve Backend'e Gönderme
function handleFormSubmit(event) {
    event.preventDefault();

    const name = document.getElementById('name').value.trim();
    const email = document.getElementById('email').value.trim();
    const phone = document.getElementById('phone').value.trim();
    const subject = document.getElementById('subject').value.trim();
    const message = document.getElementById('message').value.trim();

    // Doğrulamalar (Validation)
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

    // Spring Boot üzerindeki e-posta/destek servisine istek gönder
    fetch('http://localhost:8080/api/support', { 
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
    })
    .then(async (res) => {
        const data = await res.json().catch(() => ({}));
        if (res.ok || data.success) {
            document.getElementById('formFeedback').style.color = "green";
            document.getElementById('formFeedback').innerText = "Talebiniz başarıyla iletildi!";
            document.getElementById('supportForm').reset();
        } else {
            document.getElementById('formFeedback').style.color = "red";
            document.getElementById('formFeedback').innerText = "Hata: " + (data.message || "Gönderilemedi.");
        }
    })
    .catch((err) => {
        console.error("Form Gönderme Hatası:", err);
        document.getElementById('formFeedback').style.color = "red";
        document.getElementById('formFeedback').innerText = "Sunucuya bağlanırken hata oluştu.";
    });
}