import 'package:flutter/material.dart';

import 'package:fe/theme/nightTheme.dart';


class StudentLabPolicyAcceptance {
  final String policyVersion;

  final bool privacyAcknowledged;

  final bool termsAccepted;

  final DateTime acceptedAt;


  const StudentLabPolicyAcceptance({
    required this.policyVersion,
    required this.privacyAcknowledged,
    required this.termsAccepted,
    required this.acceptedAt,
  });
}


class StudentLabPolicyPage extends StatefulWidget {
  final bool requireAcceptance;


  const StudentLabPolicyPage({
    super.key,
    this.requireAcceptance = false,
  });


  static const String policyVersion =
      '1.0';

  static const String effectiveDate =
      '17 agosto 2026';

  static const String controllerName =
      'Franz Amoroso';

  static const String controllerEmail =
      'amoroso.franz1@gmail.com';


  @override
  State<StudentLabPolicyPage> createState() =>
      _StudentLabPolicyPageState();
}


class _StudentLabPolicyPageState
    extends State<StudentLabPolicyPage> {
  final ScrollController
      _scrollController =
      ScrollController();


  bool _hasReachedEnd =
      false;

  bool _privacyAcknowledged =
      false;

  bool _termsAccepted =
      false;


  bool get _canContinue {
    return _hasReachedEnd &&
        _privacyAcknowledged &&
        _termsAccepted;
  }


  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _handleScroll,
    );

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        _handleScroll();
      },
    );
  }


  @override
  void dispose() {
    _scrollController
        .removeListener(
      _handleScroll,
    );

    _scrollController.dispose();

    super.dispose();
  }


  void _handleScroll() {
    if (
      _hasReachedEnd ||
      !_scrollController
          .hasClients
    ) {
      return;
    }

    final ScrollPosition position =
        _scrollController.position;

    final bool reachedEnd =
        position.maxScrollExtent <=
                0 ||
            position.pixels >=
                position.maxScrollExtent -
                    24;

    if (
      reachedEnd &&
      mounted
    ) {
      setState(() {
        _hasReachedEnd =
            true;
      });
    }
  }


  void _completeAcceptance() {
    if (!_canContinue) {
      return;
    }

    Navigator.pop(
      context,
      StudentLabPolicyAcceptance(
        policyVersion:
            StudentLabPolicyPage
                .policyVersion,
        privacyAcknowledged:
            true,
        termsAccepted:
            true,
        acceptedAt:
            DateTime.now(),
      ),
    );
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,

      appBar:
          AppBar(
        backgroundColor:
            AppColors.eleganceMidnight,

        foregroundColor:
            AppColors.pearlWhite,

        title:
            const Text(
          'Privacy e Policy',
        ),
      ),

      body:
          SafeArea(
        child:
            Column(
          children: [
            Expanded(
              child:
                  StudentLabPolicyDocument(
                controller:
                    _scrollController,

                padding:
                    EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  widget.requireAcceptance
                      ? 24
                      : 40,
                ),
              ),
            ),

            if (widget.requireAcceptance)
              _buildAcceptancePanel(),
          ],
        ),
      ),
    );
  }


  Widget _buildAcceptancePanel() {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.eleganceMidnight,

        boxShadow:
            [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.20,
            ),

            blurRadius:
                14,

            offset:
                const Offset(
              0,
              -4,
            ),
          ),
        ],
      ),

      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          if (!_hasReachedEnd)
            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    12,

                vertical:
                    10,
              ),

              decoration:
                  BoxDecoration(
                color:
                    AppColors.skyBlue
                        .withOpacity(
                  0.10,
                ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),

              child:
                  const Row(
                children: [
                  Icon(
                    Icons
                        .vertical_align_bottom_rounded,

                    color:
                        AppColors.skyBlue,

                    size:
                        20,
                  ),

                  SizedBox(
                    width:
                        10,
                  ),

                  Expanded(
                    child:
                        Text(
                      'Scorri fino alla fine del documento per poter confermare.',

                      style:
                          TextStyle(
                        color:
                            AppColors.pearlWhite,

                        fontSize:
                            12,

                        height:
                            1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (!_hasReachedEnd)
            const SizedBox(
              height:
                  8,
            ),

          CheckboxListTile(
            contentPadding:
                EdgeInsets.zero,

            dense:
                true,

            controlAffinity:
                ListTileControlAffinity
                    .leading,

            value:
                _privacyAcknowledged,

            onChanged:
                !_hasReachedEnd
                    ? null
                    : (
                        bool? value,
                      ) {
                        setState(() {
                          _privacyAcknowledged =
                              value ??
                                  false;
                        });
                      },

            activeColor:
                AppColors.skyBlue,

            checkColor:
                AppColors
                    .eleganceMidnight,

            title:
                const Text(
              'Dichiaro di aver letto l’Informativa Privacy.',

              style:
                  TextStyle(
                color:
                    AppColors.pearlWhite,

                fontSize:
                    12,

                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          CheckboxListTile(
            contentPadding:
                EdgeInsets.zero,

            dense:
                true,

            controlAffinity:
                ListTileControlAffinity
                    .leading,

            value:
                _termsAccepted,

            onChanged:
                !_hasReachedEnd
                    ? null
                    : (
                        bool? value,
                      ) {
                        setState(() {
                          _termsAccepted =
                              value ??
                                  false;
                        });
                      },

            activeColor:
                AppColors.skyBlue,

            checkColor:
                AppColors
                    .eleganceMidnight,

            title:
                const Text(
              'Accetto la Policy e le condizioni di utilizzo di StudentLab.',

              style:
                  TextStyle(
                color:
                    AppColors.pearlWhite,

                fontSize:
                    12,

                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          SizedBox(
            width:
                double.infinity,

            height:
                50,

            child:
                ElevatedButton(
              onPressed:
                  _canContinue
                      ? _completeAcceptance
                      : null,

              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    AppColors.socialBlue,

                foregroundColor:
                    AppColors.pureWhite,

                disabledBackgroundColor:
                    AppColors.socialBlue
                        .withOpacity(
                  0.25,
                ),

                disabledForegroundColor:
                    AppColors.pureWhite
                        .withOpacity(
                  0.40,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),

              child:
                  const Text(
                'Continua',

                style:
                    TextStyle(
                  fontSize:
                      15,

                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class StudentLabPolicyDocument
    extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  final ScrollController?
      controller;


  const StudentLabPolicyDocument({
    super.key,
    this.padding =
        const EdgeInsets.fromLTRB(
      20,
      24,
      20,
      40,
    ),
    this.controller,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      color:
          Colors.white,

      child:
          ListView(
        controller:
            controller,

        padding:
            padding,

        children: [
          const Text(
            'Informativa Privacy e Policy di utilizzo di StudentLab',

            style:
                TextStyle(
              color:
                  Color(
                0xFF111827,
              ),

              fontSize:
                  24,

              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          const Text(
            'Versione '
            '${StudentLabPolicyPage.policyVersion}'
            ' • In vigore dal '
            '${StudentLabPolicyPage.effectiveDate}',

            style:
                TextStyle(
              color:
                  Color(
                0xFF6B7280,
              ),

              fontSize:
                  12,
            ),
          ),

          const SizedBox(
            height:
                28,
          ),

          const _PolicySection(
            title:
                '1. Titolare del trattamento',

            body:
                'Il Titolare del trattamento dei dati personali effettuato attraverso StudentLab è Franz Amoroso. Per richieste relative alla privacy, all’esercizio dei diritti o al trattamento dei dati personali è possibile contattare il Titolare all’indirizzo email indicato nell’applicazione e nei relativi canali ufficiali di StudentLab.',
          ),

          const _PolicySection(
            title:
                '2. Finalità di StudentLab',

            body:
                'StudentLab è una piattaforma digitale dedicata allo studio e alla collaborazione accademica. Il servizio ha lo scopo di aiutare gli studenti durante il proprio percorso di studio, fornire accesso a materiali didattici, facilitare il ripasso e la preparazione agli esami, consentire agli utenti di ricevere o offrire supporto sulle materie, mettere in contatto studenti e insegnanti, creare gruppi di studio, favorire la condivisione di materiale didattico e consentire agli insegnanti di distribuire risorse agli studenti attraverso un unico ambiente digitale.',
          ),

          const _PolicySection(
            title:
                '3. Categorie di dati trattati',

            body:
                'StudentLab può trattare dati identificativi e di contatto, come nome, cognome, data di nascita ed email; dati relativi all’account e all’autenticazione; dati relativi al percorso accademico, tra cui ateneo, dipartimento, corso, stato del percorso, anno di inizio ed eventuale anno di laurea; dati relativi a materie, voti, insegnamenti e relative verifiche; informazioni inserite volontariamente nel profilo; preferenze relative alla disponibilità ad aiutare altri utenti o offrire lezioni private; contenuti pubblicati, materiali caricati, messaggi, gruppi, richieste di partecipazione, recensioni e segnalazioni; dati tecnici e di sicurezza necessari al funzionamento e alla protezione del servizio.',
          ),

          const _PolicySection(
            title:
                '4. Dati pubblici e dati riservati',

            body:
                'Alcune informazioni del profilo possono essere rese visibili agli altri utenti quando necessario per le funzionalità social e accademiche di StudentLab, ad esempio nome, percorso accademico, materie, disponibilità ad aiutare, insegnamenti verificati e contenuti condivisi. La data di nascita, le credenziali, le password, i token di autenticazione, i dati amministrativi, le informazioni interne di moderazione e gli altri dati tecnici o riservati non vengono mostrati agli altri utenti.',
          ),

          const _PolicySection(
            title:
                '5. Base giuridica del trattamento',

            body:
                'Il trattamento dei dati necessari alla creazione e gestione dell’account e all’erogazione delle funzionalità richieste dall’utente è effettuato perché necessario all’esecuzione del servizio richiesto. Alcuni trattamenti sono inoltre effettuati per adempiere a obblighi di legge e per perseguire il legittimo interesse del Titolare alla sicurezza della piattaforma, alla prevenzione degli abusi, alla moderazione, alla protezione degli utenti e alla corretta gestione del servizio. Qualora una specifica funzionalità richieda il consenso dell’utente, tale consenso sarà richiesto separatamente.',
          ),

          const _PolicySection(
            title:
                '6. Account e autenticazione',

            body:
                'L’utente è responsabile dell’accuratezza delle informazioni fornite durante la registrazione e della protezione delle proprie credenziali. Le password vengono gestite in forma protetta e non sono rese disponibili agli altri utenti. È vietato utilizzare account appartenenti ad altre persone, impersonare terzi o fornire intenzionalmente informazioni false.',
          ),

          const _PolicySection(
            title:
                '7. Percorsi accademici e verifiche',

            body:
                'Gli utenti possono indicare uno o più percorsi accademici e informazioni relative alla propria carriera universitaria. StudentLab può prevedere verifiche amministrative di percorsi, voti, ruoli docente e insegnamenti. Lo stato di verifica può essere mostrato agli altri utenti per distinguere le informazioni verificate da quelle dichiarate direttamente dall’utente.',
          ),

          const _PolicySection(
            title:
                '8. Docenti e insegnamenti',

            body:
                'Gli utenti che dichiarano di essere docenti possono indicare le materie e gli insegnamenti associati al proprio profilo. Tali informazioni possono essere sottoposte a verifica attraverso l’Area Docente o l’Admin Panel prima di essere considerate verificate e mostrate come tali agli studenti.',
          ),

          const _PolicySection(
            title:
                '9. Materiali didattici',

            body:
                'StudentLab consente il caricamento, il download e la condivisione di materiali didattici. I materiali possono essere personali, appartenere a un gruppo oppure essere pubblicati per una materia. La pubblicazione di materiale destinato alla community può essere sottoposta a verifica o moderazione prima di diventare visibile agli altri utenti.',
          ),

          const _PolicySection(
            title:
                '10. Proprietà intellettuale',

            body:
                'L’utente deve caricare e condividere esclusivamente contenuti per i quali dispone dei diritti necessari o per i quali la condivisione è consentita. Non è consentita la pubblicazione di materiale che violi il diritto d’autore, altri diritti di proprietà intellettuale o diritti di terzi.',
          ),

          const _PolicySection(
            title:
                '11. Gruppi di studio',

            body:
                'Gli utenti possono creare o partecipare a gruppi di studio, condividere materiali, utilizzare la chat e interagire con gli altri membri. Il proprietario e gli eventuali amministratori del gruppo possono gestire membri, richieste di partecipazione e contenuti secondo i permessi disponibili.',
          ),

          const _PolicySection(
            title:
                '12. Trasferimento della proprietà dei gruppi',

            body:
                'Quando il proprietario di un gruppo richiede l’eliminazione del proprio account o avvia un processo che richiede la cessazione della propria proprietà, deve proporre un altro membro idoneo come nuovo proprietario. Il destinatario riceve una notifica e può accettare o rifiutare. Se accetta, la proprietà viene trasferita. Se rifiuta oppure non risponde entro 30 giorni, il gruppo viene eliminato secondo le regole del servizio.',
          ),

          const _PolicySection(
            title:
                '13. Messaggi e comunicazioni',

            body:
                'StudentLab può consentire comunicazioni tra studenti, insegnanti e membri dei gruppi. I contenuti inviati attraverso le funzioni di messaggistica sono trattati per consentire la comunicazione, garantire il funzionamento del servizio, prevenire abusi e consentire interventi di moderazione quando necessari.',
          ),

          const _PolicySection(
            title:
                '14. Recensioni',

            body:
                'Gli utenti possono pubblicare recensioni e valutazioni relative alle interazioni consentite dal servizio. Le recensioni devono rappresentare esperienze reali e non possono contenere contenuti offensivi, discriminatori, fraudolenti o intenzionalmente manipolati.',
          ),

          const _PolicySection(
            title:
                '15. Moderazione e controllo dei contenuti',

            body:
                'StudentLab utilizza strumenti di moderazione attraverso l’Admin Panel e, per le funzionalità pertinenti, l’Area Docente. Profili, gruppi, recensioni, materiali, contenuti e altre informazioni pubblicate possono essere sottoposti a verifica o revisione. Gli utenti possono segnalare comportamenti, profili o contenuti ritenuti contrari alle regole della piattaforma.',
          ),

          const _PolicySection(
            title:
                '16. Minori',

            body:
                'La registrazione a StudentLab è consentita agli utenti che hanno compiuto almeno 14 anni. La data di nascita viene richiesta durante la registrazione per verificare il rispetto di tale requisito. StudentLab adotta inoltre misure di moderazione e controllo sui contenuti pubblicati e sulle funzionalità social per ridurre il rischio di contenuti inappropriati o comportamenti abusivi. Le attività pubbliche possono essere soggette alla supervisione degli strumenti di amministrazione e moderazione previsti dalla piattaforma.',
          ),

          const _PolicySection(
            title:
                '17. Sicurezza dei dati',

            body:
                'StudentLab applica misure tecniche e organizzative finalizzate alla protezione dei dati personali, tra cui autenticazione degli utenti, controllo dei ruoli e delle autorizzazioni, separazione tra dati pubblici e riservati, utilizzo di connessioni HTTPS, gestione protetta delle credenziali, controlli lato backend, moderazione amministrativa e limitazione dell’accesso ai dati in base alle funzioni dell’utente.',
          ),

          const _PolicySection(
            title:
                '18. Destinatari dei dati',

            body:
                'I dati possono essere trattati dal Titolare e dai soggetti tecnici necessari al funzionamento di StudentLab. Possono inoltre essere trattati da fornitori di infrastruttura cloud, hosting, database e archiviazione utilizzati per erogare il servizio, inclusi i servizi impiegati per il backend, il database e la conservazione dei materiali. I dati non vengono venduti agli inserzionisti o a terzi.',
          ),

          const _PolicySection(
            title:
                '19. Infrastruttura tecnica',

            body:
                'StudentLab utilizza servizi infrastrutturali esterni per il funzionamento della piattaforma, tra cui Vercel per servizi applicativi e archiviazione collegata e Neon/PostgreSQL per la gestione del database. Tali fornitori possono operare come responsabili o sub-responsabili del trattamento in relazione ai servizi forniti.',
          ),

          const _PolicySection(
            title:
                '20. Trasferimenti al di fuori dello Spazio Economico Europeo',

            body:
                'Alcuni fornitori tecnici utilizzati da StudentLab possono trattare o trasferire dati in Paesi situati al di fuori dello Spazio Economico Europeo. In tali casi il trattamento viene effettuato utilizzando gli strumenti di protezione previsti dalla normativa applicabile, quali decisioni di adeguatezza, clausole contrattuali standard o altri meccanismi giuridici riconosciuti.',
          ),

          const _PolicySection(
            title:
                '21. Conservazione dei dati durante l’utilizzo',

            body:
                'I dati dell’account vengono conservati per il periodo in cui l’account rimane attivo e per il tempo necessario a fornire le funzionalità richieste dall’utente, gestire gruppi, materiali, verifiche, segnalazioni, sicurezza e moderazione.',
          ),

          const _PolicySection(
            title:
                '22. Account inattivi',

            body:
                'Se non viene rilevato alcun accesso all’account per 6 mesi consecutivi, StudentLab invia all’utente un avviso all’indirizzo email associato all’account. L’utente dispone di ulteriori 3 mesi per effettuare un nuovo accesso. Se durante tale periodo non viene rilevato alcun accesso, viene avviata automaticamente la procedura di eliminazione dell’account.',
          ),

          const _PolicySection(
            title:
                '23. Eliminazione volontaria dell’account',

            body:
                'L’utente può richiedere in qualsiasi momento l’eliminazione del proprio account. Quando non esistono impedimenti collegati alla gestione dei gruppi, la procedura di cancellazione viene avviata immediatamente. Se l’utente è proprietario di uno o più gruppi, deve prima completare il processo di trasferimento della proprietà previsto dal servizio.',
          ),

          const _PolicySection(
            title:
                '24. Termine massimo di 30 giorni',

            body:
                'Le procedure che richiedono il trasferimento della proprietà di un gruppo hanno una durata massima di 30 giorni. Se il trasferimento viene accettato prima della scadenza, la procedura di eliminazione dell’account prosegue. Se il trasferimento viene rifiutato o non viene completato entro 30 giorni, il gruppo interessato viene eliminato e la procedura di cancellazione dell’account prosegue.',
          ),

          const _PolicySection(
            title:
                '25. Cancellazione e anonimizzazione',

            body:
                'Al completamento della procedura di eliminazione, i dati personali non più necessari vengono cancellati o anonimizzati. Quando è necessario conservare riferimenti tecnici o storici per mantenere l’integrità di gruppi, materiali, attività di moderazione, segnalazioni o altre relazioni del sistema, tali riferimenti vengono mantenuti senza consentire l’identificazione diretta dell’utente e senza permettere un nuovo accesso all’account eliminato.',
          ),

          const _PolicySection(
            title:
                '26. Dati locali sul dispositivo',

            body:
                'StudentLab può conservare localmente sul dispositivo dati necessari al funzionamento offline, materiali scaricati, cache e altre informazioni locali. La disconnessione dall’account non comporta necessariamente l’eliminazione dei materiali già scaricati sul dispositivo. L’utente può rimuovere tali dati utilizzando le funzionalità disponibili sul dispositivo o nell’app.',
          ),

          const _PolicySection(
            title:
                '27. Notifiche',

            body:
                'StudentLab utilizza notifiche interne per comunicare eventi relativi all’account, ai gruppi, alle richieste di partecipazione, ai trasferimenti di proprietà, alle verifiche, ai materiali, alle segnalazioni e ad altre attività rilevanti per il funzionamento del servizio.',
          ),

          const _PolicySection(
            title:
                '28. Email di servizio',

            body:
                'L’indirizzo email associato all’account può essere utilizzato per comunicazioni strettamente necessarie al funzionamento e alla sicurezza del servizio, incluse comunicazioni relative all’account, procedure di eliminazione, inattività, sicurezza, verifiche e altre comunicazioni operative.',
          ),

          const _PolicySection(
            title:
                '29. Diritti dell’utente',

            body:
                'Nei casi previsti dalla normativa applicabile, l’utente può richiedere l’accesso ai propri dati personali, la rettifica dei dati inesatti, la cancellazione, la limitazione del trattamento, la portabilità dei dati, l’opposizione al trattamento e, quando il trattamento è basato sul consenso, la revoca del consenso senza pregiudicare la liceità del trattamento effettuato prima della revoca.',
          ),

          const _PolicySection(
            title:
                '30. Come esercitare i propri diritti',

            body:
                'Le richieste relative ai dati personali possono essere inviate al Titolare utilizzando il contatto privacy indicato da StudentLab. Prima di completare una richiesta può essere necessario verificare l’identità del richiedente per impedire accessi o modifiche non autorizzate ai dati.',
          ),

          const _PolicySection(
            title:
                '31. Reclamo all’Autorità di controllo',

            body:
                'L’utente ha il diritto di proporre reclamo all’Autorità Garante per la protezione dei dati personali o all’autorità di controllo competente qualora ritenga che il trattamento dei propri dati personali avvenga in violazione della normativa applicabile.',
          ),

          const _PolicySection(
            title:
                '32. Contenuti vietati',

            body:
                'Non è consentita la pubblicazione o trasmissione di contenuti illegali, offensivi, discriminatori, molesti, fraudolenti, ingannevoli, pericolosi, contenenti malware, spam, materiale illecito o contenuti che violino i diritti di terzi.',
          ),

          const _PolicySection(
            title:
                '33. Abusi della piattaforma',

            body:
                'È vietato tentare di aggirare sistemi di autenticazione o autorizzazione, ottenere accesso a dati non autorizzati, compromettere il funzionamento del servizio, manipolare verifiche o recensioni, utilizzare account falsi o interferire con gli altri utenti.',
          ),

          const _PolicySection(
            title:
                '34. Sospensione e limitazione degli account',

            body:
                'StudentLab può limitare, sospendere o disattivare un account quando ciò è necessario per proteggere gli utenti, prevenire abusi, gestire violazioni delle regole, adempiere a obblighi di legge o garantire la sicurezza e l’integrità della piattaforma.',
          ),

          const _PolicySection(
            title:
                '35. Modifiche alla Privacy Policy',

            body:
                'La presente informativa può essere aggiornata quando cambiano le funzionalità del servizio, le modalità di trattamento dei dati, i fornitori tecnici o la normativa applicabile. In caso di modifiche significative StudentLab informa gli utenti e, quando necessario, richiede una nuova presa visione o accettazione.',
          ),

          const _PolicySection(
            title:
                '36. Presa visione e accettazione',

            body:
                'Prima di completare la registrazione, l’utente deve scorrere integralmente l’informativa. Solo dopo aver raggiunto la fine del documento viene resa disponibile la conferma con cui l’utente dichiara di aver letto l’Informativa Privacy e di accettare la Policy di utilizzo di StudentLab.',
          ),

          const SizedBox(
            height:
                16,
          ),

          Container(
            padding:
                const EdgeInsets.all(
              18,
            ),

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF3F4F6,
              ),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),

              border:
                  Border.all(
                color:
                    const Color(
                  0xFFE5E7EB,
                ),
              ),
            ),

            child:
                const Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'Titolare del trattamento',

                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFF111827,
                    ),

                    fontSize:
                        14,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(
                  height:
                      8,
                ),

                Text(
                  StudentLabPolicyPage
                      .controllerName,

                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFF374151,
                    ),

                    fontSize:
                        13,
                  ),
                ),

                SizedBox(
                  height:
                      4,
                ),

                Text(
                  StudentLabPolicyPage
                      .controllerEmail,

                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFF2563EB,
                    ),

                    fontSize:
                        13,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _PolicySection
    extends StatelessWidget {
  final String title;

  final String body;


  const _PolicySection({
    required this.title,
    required this.body,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom:
            24,
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style:
                const TextStyle(
              color:
                  Color(
                0xFF111827,
              ),

              fontSize:
                  16,

              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          Text(
            body,

            style:
                const TextStyle(
              color:
                  Color(
                0xFF4B5563,
              ),

              fontSize:
                  13,

              height:
                  1.6,
            ),
          ),
        ],
      ),
    );
  }
}