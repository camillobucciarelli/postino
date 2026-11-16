"""Riempie le due caselle demo del server finto (GreenMail, vedi README.md) con posta inventata.

Uso: python3 -I seed.py <it|en> <ca.pem>. Solo nomi inventati e domini example.com/example.org.
"""

import imaplib
import ssl
import sys
import time
from email.message import EmailMessage
from email.utils import format_datetime, make_msgid
from datetime import datetime, timedelta, timezone

PASSWORD = 'demo-pass'
NOW = datetime.now(timezone.utc).astimezone()

# (mittente, oggetto, testo, ore fa, flag): flag tra 'unread', 'star', 'pdf', 'html'.
IT = {
    'demo@example.com': [
        ('Marta Ferri <marta.ferri@example.com>', 'Revisione del progetto Aurora', 'Ciao, ti mando la bozza del capitolato: dimmi se va bene entro venerdì.', 0.3, 'unread star pdf'),
        ('Luca Conti <luca.conti@example.com>', 'Riunione di lunedì spostata alle 10', 'La sala grande è occupata, ci vediamo nella saletta al secondo piano.', 1.2, 'unread'),
        ('Ufficio viaggi <viaggi@example.org>', 'Conferma prenotazione: Milano → Roma', 'Il tuo biglietto è confermato. Partenza ore 8:15, carrozza 5, posto 12A.', 3, 'star html'),
        ('Elena Russo <elena.russo@example.com>', 'Budget del quarto trimestre', 'Ho aggiornato il foglio con le ultime voci di spesa. Ci sono due punti da chiarire.', 5, 'pdf'),
        ('Notizie Tech <newsletter@example.org>', 'Le novità della settimana', 'Cinque strumenti per lavorare meglio offline.', 8, 'html'),
        ('Giorgio Bassi <giorgio.bassi@example.com>', 'Pranzo di squadra giovedì?', 'Pensavo alla trattoria in piazza, alle 13. Chi c\'è?', 20, 'unread'),
        ('Assistenza Cloud <support@example.org>', 'Il tuo spazio di archiviazione', 'Hai usato l\'80% dello spazio disponibile.', 26, ''),
        ('Sara Marino <sara.marino@example.com>', 'Presentazione per il cliente', 'Ho rifatto le slide 4-7, trovi tutto nella cartella condivisa.', 30, 'star'),
        ('Davide Greco <davide.greco@example.com>', 'Ferie di dicembre', 'Ricordati di segnare le ferie nel calendario entro il 30.', 50, ''),
        ('Biblioteca civica <prestiti@example.org>', 'Promemoria restituzione', 'Il libro «Il nome della rosa» va restituito entro il 22 novembre.', 72, ''),
        ('Paolo Rinaldi <paolo.rinaldi@example.com>', 'Contratto fornitura 2027', 'In allegato la versione firmata del contratto.', 96, 'pdf'),
        ('Chiara Villa <chiara.villa@example.com>', 'Grazie per l\'aiuto!', 'La demo è andata benissimo, il cliente ha già chiesto un preventivo.', 120, ''),
    ],
    'demo@example.org': [
        ('Anna Bellini <anna.bellini@example.org>', 'Foto della gita in montagna', 'Ecco le foto di domenica! La vista dal rifugio era incredibile.', 0.8, 'unread html'),
        ('Palestra Centro <info@example.org>', 'Nuovi orari del corso di yoga', 'Da dicembre il corso del martedì inizia alle 19:30.', 2, 'unread'),
        ('Marco Galli <marco.galli@example.org>', 'Cena di sabato', 'Porto io il dolce. Serve altro?', 4, 'star'),
        ('Libreria Pagine <ordini@example.org>', 'Il tuo ordine è stato spedito', 'Il pacco arriverà tra due o tre giorni lavorativi.', 10, 'html'),
        ('Zia Laura <laura.demo@example.org>', 'Ricetta del tiramisù', 'Come promesso, ecco la ricetta: mascarpone, savoiardi e tanto caffè.', 28, 'star'),
        ('Comune di Esempio <servizi@example.org>', 'Rinnovo carta d\'identità', 'Il tuo appuntamento è fissato per il 3 dicembre alle 9:00.', 60, ''),
        ('Federica Sala <federica.sala@example.org>', 'Concerto a gennaio', 'Ho trovato i biglietti, ne prendo due anche per voi?', 90, ''),
    ],
}

EN = {
    'demo@example.com': [
        ('Martha Fields <martha.fields@example.com>', 'Project Aurora review', 'Hi, here is the draft spec: let me know if it works for you by Friday.', 0.3, 'unread star pdf'),
        ('Luke Carter <luke.carter@example.com>', 'Monday meeting moved to 10am', 'The main room is booked, let\'s meet in the small room on the second floor.', 1.2, 'unread'),
        ('Travel Desk <travel@example.org>', 'Booking confirmed: London → Edinburgh', 'Your ticket is confirmed. Departure 8:15am, coach C, seat 12A.', 3, 'star html'),
        ('Ellen Ross <ellen.ross@example.com>', 'Q4 budget', 'I updated the sheet with the latest expenses. Two items need a closer look.', 5, 'pdf'),
        ('Tech Weekly <newsletter@example.org>', 'This week in tech', 'Five tools to work better offline.', 8, 'html'),
        ('George Bailey <george.bailey@example.com>', 'Team lunch on Thursday?', 'Thinking of the diner on the square, at 1pm. Who\'s in?', 20, 'unread'),
        ('Cloud Support <support@example.org>', 'Your storage', 'You have used 80% of your available storage.', 26, ''),
        ('Sarah Morgan <sarah.morgan@example.com>', 'Client presentation', 'I reworked slides 4-7, everything is in the shared folder.', 30, 'star'),
        ('David Green <david.green@example.com>', 'December holidays', 'Remember to add your holidays to the calendar by the 30th.', 50, ''),
        ('City Library <loans@example.org>', 'Return reminder', 'Your book "Pride and Prejudice" is due back by November 22.', 72, ''),
        ('Paul Reynolds <paul.reynolds@example.com>', '2027 supply contract', 'Attached is the signed version of the contract.', 96, 'pdf'),
        ('Claire Wells <claire.wells@example.com>', 'Thanks for your help!', 'The demo went great, the client already asked for a quote.', 120, ''),
    ],
    'demo@example.org': [
        ('Anna Bell <anna.bell@example.org>', 'Photos from the hike', 'Here are the photos from Sunday! The view from the hut was amazing.', 0.8, 'unread html'),
        ('Downtown Gym <info@example.org>', 'New yoga class times', 'From December the Tuesday class starts at 7:30pm.', 2, 'unread'),
        ('Mark Gale <mark.gale@example.org>', 'Saturday dinner', 'I\'ll bring dessert. Anything else?', 4, 'star'),
        ('Pages Bookshop <orders@example.org>', 'Your order has shipped', 'Your parcel will arrive in two to three business days.', 10, 'html'),
        ('Aunt Laura <laura.demo@example.org>', 'Pancake recipe', 'As promised, here is the recipe: flour, eggs, milk and a pinch of salt.', 28, 'star'),
        ('Example Council <services@example.org>', 'ID card renewal', 'Your appointment is on December 3 at 9:00am.', 60, ''),
        ('Fiona Hale <fiona.hale@example.org>', 'Concert in January', 'I found tickets, shall I get two for you as well?', 90, ''),
    ],
}

# La conversazione (Account example.com): (mittente o None = noi, testo, ore fa).
THREAD = {
    'it': ('Lancio della nuova app', [
        ('Marta Ferri <marta.ferri@example.com>', 'Ciao a tutti, propongo di fissare il lancio al 1° dicembre. Vi torna?', 30),
        (None, 'Per me va bene. Preparo io la nota per la stampa entro mercoledì.', 26),
        ('Luca Conti <luca.conti@example.com>', 'D\'accordo anche io. Allego il calendario con le attività della settimana.', 6),
        ('Marta Ferri <marta.ferri@example.com>', 'Perfetto, grazie! Ecco anche l\'anteprima della pagina: guardala e dimmi cosa ne pensi.', 0.1),
    ]),
    'en': ('New app launch', [
        ('Martha Fields <martha.fields@example.com>', 'Hi all, I suggest we set the launch for December 1. Does that work?', 30),
        (None, 'Works for me. I\'ll prepare the press note by Wednesday.', 26),
        ('Luke Carter <luke.carter@example.com>', 'Agreed. Attached is the calendar with the week\'s tasks.', 6),
        ('Martha Fields <martha.fields@example.com>', 'Perfect, thanks! Here is the page preview too: have a look and tell me what you think.', 0.1),
    ]),
}

EXTRA = {  # cartella: (oggetto, testo)
    'it': {'Drafts': ('Proposta per il workshop', 'Bozza: tre giornate a febbraio, tema sicurezza dei dati.'),
           'Trash': ('Offerta scaduta', 'Solo per oggi: sconto del 50%.'),
           'Progetti': ('Verbale riunione Aurora', 'Decisioni prese e prossimi passi.')},
    'en': {'Drafts': ('Workshop proposal', 'Draft: three days in February, topic data security.'),
           'Trash': ('Expired offer', 'Today only: 50% off.'),
           'Progetti': ('Aurora meeting minutes', 'Decisions taken and next steps.')},
}
FOLDERS = {'it': ['Sent', 'Drafts', 'Trash', 'Progetti', 'Viaggi'], 'en': ['Sent', 'Drafts', 'Trash', 'Projects', 'Travel']}

PDF = (b'%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj '
       b'3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n')


def message(sender, to, subject, text, hours, flags, lang, reply_to=None):
    m = EmailMessage()
    m['From'], m['To'], m['Subject'] = sender, to, subject
    m['Date'] = format_datetime(NOW - timedelta(hours=hours))
    m['Message-ID'] = make_msgid(domain=sender.split('@')[-1].rstrip('>'))
    if reply_to:
        m['In-Reply-To'], m['References'] = reply_to[-1], ' '.join(reply_to)
    m.set_content(text)
    if 'html' in flags:
        # Immagine remota su example.com: l'app la blocca e mostra il banner.
        m.add_alternative(f'<html><body style="font-family:sans-serif"><img src="https://www.example.com/banner.jpg" '
                          f'width="560" height="200" alt=""><p>{text}</p></body></html>', subtype='html')
    if 'pdf' in flags:
        it = lang == 'it'
        name = (('anteprima.pdf' if it else 'preview.pdf') if 'html' in flags
                else ('calendario.pdf' if it else 'schedule.pdf') if 'Re:' in subject
                else ('documento.pdf' if it else 'document.pdf'))
        m.add_attachment(PDF, maintype='application', subtype='pdf', filename=name)
    return m


def append(c, folder, m, flags, hours):
    imap_flags = ' '.join(f for f, on in (('\\Seen', 'unread' not in flags), ('\\Flagged', 'star' in flags)) if on)
    when = imaplib.Time2Internaldate(time.time() - hours * 3600)
    ok, _ = c.append(folder, f'({imap_flags})', when, m.as_bytes())
    assert ok == 'OK', (folder, m['Subject'])


def main():
    lang, ca = sys.argv[1], sys.argv[2]
    ctx = ssl.create_default_context(cafile=ca)
    for box, mails in (IT if lang == 'it' else EN).items():
        c = imaplib.IMAP4_SSL('localhost', 3993, ssl_context=ctx)
        c.login(box, PASSWORD)
        me = f'Demo <{box}>'
        for f in FOLDERS[lang]:
            c.create(f)
        for sender, subject, text, hours, flags in mails:
            append(c, 'INBOX', message(sender, me, subject, text, hours, flags, lang), flags, hours)
        if box.endswith('.com'):
            subject, turns = THREAD[lang]
            ids = []
            for i, (sender, text, hours) in enumerate(turns):
                flags = ('pdf ' if i == 2 else '') + ('unread html pdf' if i == 3 else '')
                subj = subject if i == 0 else 'Re: ' + subject
                m = message(sender or me, 'Team <team@example.com>', subj, text, hours, flags, lang, ids or None)
                ids.append(m['Message-ID'])
                append(c, 'Sent' if sender is None else 'INBOX', m, flags, hours)
            for folder, (subject, text) in EXTRA[lang].items():
                folder = FOLDERS[lang][3] if folder == 'Progetti' else folder
                to = 'Team <team@example.com>' if folder == 'Drafts' else me
                append(c, folder, message(me if folder == 'Drafts' else 'Marta <marta@example.com>', to, subject, text, 40, '', lang), '', 40)
        c.logout()
        print(box, 'ok')


if __name__ == '__main__':
    main()
