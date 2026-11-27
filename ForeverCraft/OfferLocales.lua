local _, addon = ...
-- UI texts of the crafting offers (merged into the existing catalogs of Locale.lua and
-- ClientLocales.lua). The chat phrases themselves live in Offers.lua, per message language.
local texts = {}

texts.enUS = {
    offerButton = "Offer crafting",
    offerTooltip = "Offer your crafting professions in the trade chat. You decide which professions you offer and on which terms you craft.",
    offerTooltipClicks = "Left-click: open the offer window\nRight-click: saved offer profiles\nShift + left-click: post the last offer right away",
    offerQuickDisabled = "Quick posting is off (enable it in the settings).",
    offerTitle = "ForeverCraft · Offer crafting",
    offerProfessions = "Professions you offer", offerGathering = "Gathering profession",
    offerNoProfessions = "No professions found on this character.",
    offerPerProfession = "Set terms per profession", offerConditions = "Terms",
    cond_mats = "Customer brings the mats", cond_matsTip = "Mats + voluntary tip", cond_matsPaid = "Mats + tip",
    cond_matsFixed = "Mats + fixed fee", cond_ownMats = "I bring the mats", cond_negotiable = "Mats by arrangement",
    cond_free = "Free with your mats", cond_leveling = "Leveling: free with your mats", cond_custom = "Custom terms",
    offerCustomConditions = "Your own terms", offerFee = "Fee", offerFeeEach = "per craft", offerFeeTotal = "per order (total price)",
    offerFeeNote = "ForeverCraft only writes down your offer. Gold and items are never moved automatically.",
    offerRecipes = "Special recipes", offerRecipesCount = "%d recipes selected", offerRecipesNone = "No recipes selected",
    offerChooseRecipes = "Choose recipes…", offerClearRecipes = "Clear", offerRecipeSearch = "Search recipe",
    offerRecipeAllCategories = "All categories",
    offerRecipeBound = "Binds when picked up – cannot be handed over", offerRecipeLoading = "Loading item data…",
    offerRecipeCooldown = "Cooldown: %s left", offerRecipeService = "Service", offerRecipesDone = "Done",
    offerProfile = "Profile", offerProfileDefault = "Standard offer", offerProfileSave = "Save", offerProfileNew = "New profile",
    offerProfileDelete = "Delete", offerProfileName = "Profile name", offerProfileDeleteConfirm = "Delete the profile “%s”?",
    offerTemplate = "Template", template_casual = "Casual and friendly", template_short = "Short and direct",
    offerManageTemplates = "Own templates…", offerLanguage = "Message language", offerLanguageAuto = "Same as client",
    offerChannel = "Channel", channel_trade = "Trade chat", channel_guild = "Guild chat", channel_general = "General chat",
    offerOptions = "Options",
    opt_showSkill = "Show profession skill", opt_showMax = "Show maximum skill",
    opt_professionLinks = "Insert profession links (if the client supports them)", opt_recipeLinks = "Insert item and recipe links",
    opt_highlightRecipes = "Highlight selected recipes", opt_showConditions = "Show terms", opt_askWhisper = "Ask for a whisper",
    offerPreview = "Preview (you can edit it)",
    offerEmpty = "Pick at least one profession or recipe.", offerRegenerate = "Rebuild text", offerPost = "Post",
    offerPostWait = "Wait (%d s)", offerConfirm = "Send this offer to “%s”?\n\n%s", offerSent = "Sent to %s.",
    offerConfirmed = "The message appeared in the chat.",
    offerNotConfirmed = "The message did not appear in the chat. The client may have blocked it.",
    offerTradeUnavailable = "The trade chat isn't available here right now. Head to a city or pick a different chat channel.",
    offerChannelUnavailable = "The channel “%s” isn't available right now.", offerGuildUnavailable = "You are not in a guild.",
    offerCooldownActive = "Please wait %d more seconds (local protection against double posts).",
    offerQuickOff = "Quick posting is turned off in the settings.", offerNoLast = "There is no last used offer yet.",
    templatesTitle = "ForeverCraft · Own message templates", templateNew = "New", templateDuplicate = "Duplicate",
    templateSave = "Save", templateDelete = "Delete", templateName = "Name", templateDefaultName = "My template",
    templatePlaceholders = "Placeholders: {berufe} {berufe_skill} {rezepte} {konditionen} {verguetung} {charakter} {berufslinks} {rezeptlinks} (English: {professions} {recipes} …). Lines whose placeholder stays empty are left out.",
    templateNone = "No own templates yet.",
    settingsOffers = "Crafting offers", settingsOffersMessage = "Message", settingsOffersPosting = "Posting",
    settingsOffersDetail = "Every post needs a click. The waiting time is a local protection and does not replace the server's chat rules.",
    settingsOfferQuick = "Quick posting with Shift + left-click", settingsOfferPreview = "Show message preview",
    settingsOfferConfirm = "Confirm before sending", settingsOfferCooldown = "Waiting time: %d s",
    settingsOfferCondition = "Default terms: %s", settingsOfferChannel = "Default channel: %s",
    settingsOfferLanguage = "Message language: %s", settingsOfferTemplate = "Default template: %s",
    settingsOfferOpen = "Open offer window", settingsOfferTemplates = "Manage own templates",
}

texts.deDE = {
    offerButton = "Handwerk anbieten",
    offerTooltip = "Biete deine Handwerksberufe im Handelschat an. Du kannst selbst festlegen, welche Berufe du anbietest und unter welchen Bedingungen du etwas herstellst.",
    offerTooltipClicks = "Linksklick: Angebotsfenster öffnen\nRechtsklick: Gespeicherte Angebotsprofile\nShift + Linksklick: Letztes Angebot direkt veröffentlichen",
    offerQuickDisabled = "Schnellveröffentlichung ist aus (in den Einstellungen aktivierbar).",
    offerTitle = "ForeverCraft · Handwerk anbieten",
    offerProfessions = "Angebotene Berufe", offerGathering = "Sammelberuf",
    offerNoProfessions = "Auf diesem Charakter wurden keine Berufe gefunden.",
    offerPerProfession = "Konditionen pro Beruf festlegen", offerConditions = "Konditionen",
    cond_mats = "Gegen Materialien", cond_matsTip = "Materialien und freiwilliges Trinkgeld", cond_matsPaid = "Materialien und Trinkgeld",
    cond_matsFixed = "Materialien und feste Vergütung", cond_ownMats = "Eigene Materialien", cond_negotiable = "Materialien nach Absprache",
    cond_free = "Kostenlos gegen Materialien", cond_leveling = "Beruf leveln", cond_custom = "Individuelles Angebot",
    offerCustomConditions = "Eigene Konditionen", offerFee = "Vergütung", offerFeeEach = "pro Herstellung", offerFeeTotal = "pro Auftrag (Gesamtpreis)",
    offerFeeNote = "ForeverCraft hält nur dein Angebot fest. Gold oder Gegenstände werden nie automatisch übertragen.",
    offerRecipes = "Besondere Rezepte", offerRecipesCount = "%d Rezepte ausgewählt", offerRecipesNone = "Keine Rezepte ausgewählt",
    offerChooseRecipes = "Rezepte auswählen…", offerClearRecipes = "Leeren", offerRecipeSearch = "Rezept suchen",
    offerRecipeAllCategories = "Alle Kategorien",
    offerRecipeBound = "Wird beim Aufheben gebunden – nicht übergebbar", offerRecipeLoading = "Gegenstandsdaten werden geladen …",
    offerRecipeCooldown = "Abklingzeit: noch %s", offerRecipeService = "Dienstleistung", offerRecipesDone = "Fertig",
    offerProfile = "Profil", offerProfileDefault = "Standardangebot", offerProfileSave = "Speichern", offerProfileNew = "Neues Profil",
    offerProfileDelete = "Löschen", offerProfileName = "Profilname", offerProfileDeleteConfirm = "Profil „%s“ löschen?",
    offerTemplate = "Vorlage", template_casual = "Locker und freundlich", template_short = "Kurz und direkt",
    offerManageTemplates = "Eigene Vorlagen…", offerLanguage = "Sprache der Nachricht", offerLanguageAuto = "Wie der Client",
    offerChannel = "Kanal", channel_trade = "Handelschat", channel_guild = "Gildenchat", channel_general = "Allgemeiner Chat",
    offerOptions = "Optionen",
    opt_showSkill = "Berufsfertigkeit anzeigen", opt_showMax = "Maximale Berufsfertigkeit anzeigen",
    opt_professionLinks = "Berufslinks einfügen (falls vom Client unterstützt)", opt_recipeLinks = "Gegenstands- und Rezeptlinks einfügen",
    opt_highlightRecipes = "Ausgewählte Rezepte hervorheben", opt_showConditions = "Angebotsbedingungen anzeigen",
    opt_askWhisper = "Um eine Flüsternachricht bitten",
    offerPreview = "Vorschau (bearbeitbar)",
    offerEmpty = "Wähle mindestens einen Beruf oder ein Rezept aus.", offerRegenerate = "Text neu erzeugen", offerPost = "Veröffentlichen",
    offerPostWait = "Warten (%d s)", offerConfirm = "Dieses Angebot in „%s“ senden?\n\n%s", offerSent = "Gesendet an %s.",
    offerConfirmed = "Die Nachricht ist im Chat erschienen.",
    offerNotConfirmed = "Die Nachricht ist nicht im Chat erschienen. Möglicherweise hat der Client sie blockiert.",
    offerTradeUnavailable = "Der Handelschat ist hier gerade nicht verfügbar. Begib dich in eine entsprechende Stadt oder wähle einen anderen Chatkanal aus.",
    offerChannelUnavailable = "Der Kanal „%s“ ist gerade nicht verfügbar.", offerGuildUnavailable = "Du bist in keiner Gilde.",
    offerCooldownActive = "Bitte warte noch %d Sekunden (lokaler Schutz vor Doppelposts).",
    offerQuickOff = "Die Schnellveröffentlichung ist in den Einstellungen ausgeschaltet.", offerNoLast = "Es gibt noch kein zuletzt verwendetes Angebot.",
    templatesTitle = "ForeverCraft · Eigene Nachrichtenvorlagen", templateNew = "Neu", templateDuplicate = "Duplizieren",
    templateSave = "Speichern", templateDelete = "Löschen", templateName = "Name", templateDefaultName = "Meine Vorlage",
    templatePlaceholders = "Platzhalter: {berufe} {berufe_skill} {rezepte} {konditionen} {verguetung} {charakter} {berufslinks} {rezeptlinks}. Zeilen, deren Platzhalter leer bleibt, entfallen.",
    templateNone = "Noch keine eigenen Vorlagen.",
    settingsOffers = "Handwerksangebote", settingsOffersMessage = "Nachricht", settingsOffersPosting = "Veröffentlichen",
    settingsOffersDetail = "Jede Veröffentlichung braucht einen Klick. Die Wartezeit ist ein lokaler Schutz und ersetzt keine Chatregeln des Servers.",
    settingsOfferQuick = "Schnellveröffentlichung mit Shift + Linksklick", settingsOfferPreview = "Nachrichtenvorschau anzeigen",
    settingsOfferConfirm = "Bestätigung vor dem Absenden", settingsOfferCooldown = "Wartezeit: %d s",
    settingsOfferCondition = "Standardkondition: %s", settingsOfferChannel = "Standardkanal: %s",
    settingsOfferLanguage = "Nachrichtensprache: %s", settingsOfferTemplate = "Standardvorlage: %s",
    settingsOfferOpen = "Angebotsfenster öffnen", settingsOfferTemplates = "Eigene Vorlagen verwalten",
}

texts.frFR = {
    offerButton = "Proposer mon artisanat",
    offerTooltip = "Proposez vos métiers d'artisanat dans le canal Commerce. Vous choisissez quels métiers vous proposez et à quelles conditions vous fabriquez.",
    offerTooltipClicks = "Clic gauche : ouvrir la fenêtre d'annonce\nClic droit : profils d'annonce enregistrés\nMaj + clic gauche : publier directement la dernière annonce",
    offerQuickDisabled = "Publication rapide désactivée (activable dans les options).",
    offerTitle = "ForeverCraft · Proposer mon artisanat",
    offerProfessions = "Métiers proposés", offerGathering = "Métier de récolte",
    offerNoProfessions = "Aucun métier trouvé sur ce personnage.",
    offerPerProfession = "Conditions par métier", offerConditions = "Conditions",
    cond_mats = "Contre vos compos", cond_matsTip = "Compos + pourboire libre", cond_matsPaid = "Compos + pourboire",
    cond_matsFixed = "Compos + prix fixe", cond_ownMats = "Mes propres compos", cond_negotiable = "Compos à voir ensemble",
    cond_free = "Gratuit contre vos compos", cond_leveling = "Je monte mon métier", cond_custom = "Offre personnalisée",
    offerCustomConditions = "Vos propres conditions", offerFee = "Prix", offerFeeEach = "par craft", offerFeeTotal = "par commande (prix total)",
    offerFeeNote = "ForeverCraft note seulement votre offre. L'or et les objets ne sont jamais transférés automatiquement.",
    offerRecipes = "Recettes particulières", offerRecipesCount = "%d recettes choisies", offerRecipesNone = "Aucune recette choisie",
    offerChooseRecipes = "Choisir des recettes…", offerClearRecipes = "Vider", offerRecipeSearch = "Chercher une recette",
    offerRecipeAllCategories = "Toutes les catégories",
    offerRecipeBound = "Lié quand ramassé – impossible à donner", offerRecipeLoading = "Chargement des objets…",
    offerRecipeCooldown = "Temps de recharge : encore %s", offerRecipeService = "Service", offerRecipesDone = "Terminé",
    offerProfile = "Profil", offerProfileDefault = "Annonce standard", offerProfileSave = "Enregistrer", offerProfileNew = "Nouveau profil",
    offerProfileDelete = "Supprimer", offerProfileName = "Nom du profil", offerProfileDeleteConfirm = "Supprimer le profil « %s » ?",
    offerTemplate = "Modèle", template_casual = "Décontracté et sympa", template_short = "Court et direct",
    offerManageTemplates = "Mes modèles…", offerLanguage = "Langue du message", offerLanguageAuto = "Comme le client",
    offerChannel = "Canal", channel_trade = "Commerce", channel_guild = "Guilde", channel_general = "Général",
    offerOptions = "Options",
    opt_showSkill = "Afficher le niveau du métier", opt_showMax = "Afficher le niveau maximum",
    opt_professionLinks = "Insérer les liens de métier (si le client les prend en charge)", opt_recipeLinks = "Insérer les liens d'objets et de recettes",
    opt_highlightRecipes = "Mettre en avant les recettes choisies", opt_showConditions = "Afficher les conditions", opt_askWhisper = "Demander un MP",
    offerPreview = "Aperçu (modifiable)",
    offerEmpty = "Choisissez au moins un métier ou une recette.", offerRegenerate = "Recréer le texte", offerPost = "Publier",
    offerPostWait = "Attendre (%d s)", offerConfirm = "Envoyer cette annonce dans « %s » ?\n\n%s", offerSent = "Envoyé dans %s.",
    offerConfirmed = "Le message est apparu dans le chat.",
    offerNotConfirmed = "Le message n'est pas apparu dans le chat. Le client l'a peut-être bloqué.",
    offerTradeUnavailable = "Le canal Commerce n'est pas disponible ici. Rendez-vous dans une ville ou choisissez un autre canal.",
    offerChannelUnavailable = "Le canal « %s » n'est pas disponible pour le moment.", offerGuildUnavailable = "Vous n'êtes dans aucune guilde.",
    offerCooldownActive = "Patientez encore %d secondes (protection locale contre les doubles annonces).",
    offerQuickOff = "La publication rapide est désactivée dans les options.", offerNoLast = "Aucune annonce utilisée pour l'instant.",
    templatesTitle = "ForeverCraft · Mes modèles de message", templateNew = "Nouveau", templateDuplicate = "Dupliquer",
    templateSave = "Enregistrer", templateDelete = "Supprimer", templateName = "Nom", templateDefaultName = "Mon modèle",
    templatePlaceholders = "Variables : {berufe} {berufe_skill} {rezepte} {konditionen} {verguetung} {charakter} {berufslinks} {rezeptlinks} (ou {professions} {recipes} …). Les lignes dont la variable reste vide sont omises.",
    templateNone = "Aucun modèle personnel pour l'instant.",
    settingsOffers = "Annonces d'artisanat", settingsOffersMessage = "Message", settingsOffersPosting = "Publication",
    settingsOffersDetail = "Chaque publication demande un clic. Le délai est une protection locale et ne remplace pas les règles du serveur.",
    settingsOfferQuick = "Publication rapide avec Maj + clic gauche", settingsOfferPreview = "Afficher l'aperçu du message",
    settingsOfferConfirm = "Confirmer avant l'envoi", settingsOfferCooldown = "Délai : %d s",
    settingsOfferCondition = "Conditions par défaut : %s", settingsOfferChannel = "Canal par défaut : %s",
    settingsOfferLanguage = "Langue du message : %s", settingsOfferTemplate = "Modèle par défaut : %s",
    settingsOfferOpen = "Ouvrir la fenêtre d'annonce", settingsOfferTemplates = "Gérer mes modèles",
}

texts.esES = {
    offerButton = "Ofrecer artesanía",
    offerTooltip = "Ofrece tus profesiones de fabricación en el chat de Comercio. Tú decides qué profesiones ofreces y en qué condiciones fabricas.",
    offerTooltipClicks = "Clic izquierdo: abrir la ventana de oferta\nClic derecho: perfiles de oferta guardados\nMayús + clic izquierdo: publicar directamente la última oferta",
    offerQuickDisabled = "Publicación rápida desactivada (actívala en las opciones).",
    offerTitle = "ForeverCraft · Ofrecer artesanía",
    offerProfessions = "Profesiones ofrecidas", offerGathering = "Profesión de recolección",
    offerNoProfessions = "No se encontraron profesiones en este personaje.",
    offerPerProfession = "Condiciones por profesión", offerConditions = "Condiciones",
    cond_mats = "Con tus materiales", cond_matsTip = "Materiales + propina voluntaria", cond_matsPaid = "Materiales + propina",
    cond_matsFixed = "Materiales + precio fijo", cond_ownMats = "Mis propios materiales", cond_negotiable = "Materiales a convenir",
    cond_free = "Gratis con tus materiales", cond_leveling = "Subiendo la profesión", cond_custom = "Oferta personalizada",
    offerCustomConditions = "Tus propias condiciones", offerFee = "Precio", offerFeeEach = "por fabricación", offerFeeTotal = "por encargo (precio total)",
    offerFeeNote = "ForeverCraft solo anota tu oferta. El oro y los objetos nunca se transfieren automáticamente.",
    offerRecipes = "Recetas especiales", offerRecipesCount = "%d recetas elegidas", offerRecipesNone = "Ninguna receta elegida",
    offerChooseRecipes = "Elegir recetas…", offerClearRecipes = "Vaciar", offerRecipeSearch = "Buscar receta",
    offerRecipeAllCategories = "Todas las categorías",
    offerRecipeBound = "Se liga al recogerlo: no se puede entregar", offerRecipeLoading = "Cargando datos de objetos…",
    offerRecipeCooldown = "Reutilización: faltan %s", offerRecipeService = "Servicio", offerRecipesDone = "Listo",
    offerProfile = "Perfil", offerProfileDefault = "Oferta estándar", offerProfileSave = "Guardar", offerProfileNew = "Nuevo perfil",
    offerProfileDelete = "Eliminar", offerProfileName = "Nombre del perfil", offerProfileDeleteConfirm = "¿Eliminar el perfil «%s»?",
    offerTemplate = "Plantilla", template_casual = "Cercana y amable", template_short = "Corta y directa",
    offerManageTemplates = "Mis plantillas…", offerLanguage = "Idioma del mensaje", offerLanguageAuto = "Como el cliente",
    offerChannel = "Canal", channel_trade = "Comercio", channel_guild = "Hermandad", channel_general = "General",
    offerOptions = "Opciones",
    opt_showSkill = "Mostrar nivel de profesión", opt_showMax = "Mostrar nivel máximo",
    opt_professionLinks = "Insertar enlaces de profesión (si el cliente los admite)", opt_recipeLinks = "Insertar enlaces de objetos y recetas",
    opt_highlightRecipes = "Destacar las recetas elegidas", opt_showConditions = "Mostrar las condiciones", opt_askWhisper = "Pedir un susurro",
    offerPreview = "Vista previa (editable)",
    offerEmpty = "Elige al menos una profesión o una receta.", offerRegenerate = "Volver a crear el texto", offerPost = "Publicar",
    offerPostWait = "Espera (%d s)", offerConfirm = "¿Enviar esta oferta a «%s»?\n\n%s", offerSent = "Enviado a %s.",
    offerConfirmed = "El mensaje ha aparecido en el chat.",
    offerNotConfirmed = "El mensaje no ha aparecido en el chat. Puede que el cliente lo haya bloqueado.",
    offerTradeUnavailable = "El chat de Comercio no está disponible aquí ahora mismo. Ve a una ciudad o elige otro canal.",
    offerChannelUnavailable = "El canal «%s» no está disponible ahora mismo.", offerGuildUnavailable = "No perteneces a ninguna hermandad.",
    offerCooldownActive = "Espera %d segundos más (protección local contra mensajes repetidos).",
    offerQuickOff = "La publicación rápida está desactivada en las opciones.", offerNoLast = "Todavía no hay una oferta usada.",
    templatesTitle = "ForeverCraft · Mis plantillas de mensaje", templateNew = "Nueva", templateDuplicate = "Duplicar",
    templateSave = "Guardar", templateDelete = "Eliminar", templateName = "Nombre", templateDefaultName = "Mi plantilla",
    templatePlaceholders = "Variables: {berufe} {berufe_skill} {rezepte} {konditionen} {verguetung} {charakter} {berufslinks} {rezeptlinks} (o {professions} {recipes} …). Las líneas cuya variable queda vacía se omiten.",
    templateNone = "Aún no hay plantillas propias.",
    settingsOffers = "Ofertas de artesanía", settingsOffersMessage = "Mensaje", settingsOffersPosting = "Publicación",
    settingsOffersDetail = "Cada publicación requiere un clic. La espera es una protección local y no sustituye las normas del servidor.",
    settingsOfferQuick = "Publicación rápida con Mayús + clic izquierdo", settingsOfferPreview = "Mostrar vista previa del mensaje",
    settingsOfferConfirm = "Confirmar antes de enviar", settingsOfferCooldown = "Espera: %d s",
    settingsOfferCondition = "Condiciones por defecto: %s", settingsOfferChannel = "Canal por defecto: %s",
    settingsOfferLanguage = "Idioma del mensaje: %s", settingsOfferTemplate = "Plantilla por defecto: %s",
    settingsOfferOpen = "Abrir ventana de oferta", settingsOfferTemplates = "Gestionar mis plantillas",
}

texts.ptBR = {
    offerButton = "Oferecer profissões",
    offerTooltip = "Ofereça suas profissões de criação no canal de Comércio. Você decide quais profissões oferece e em quais condições faz os itens.",
    offerTooltipClicks = "Clique esquerdo: abrir a janela de oferta\nClique direito: perfis de oferta salvos\nShift + clique esquerdo: publicar direto a última oferta",
    offerQuickDisabled = "Publicação rápida desligada (ative nas opções).",
    offerTitle = "ForeverCraft · Oferecer profissões",
    offerProfessions = "Profissões oferecidas", offerGathering = "Profissão de coleta",
    offerNoProfessions = "Nenhuma profissão encontrada neste personagem.",
    offerPerProfession = "Condições por profissão", offerConditions = "Condições",
    cond_mats = "Com seus materiais", cond_matsTip = "Materiais + gorjeta opcional", cond_matsPaid = "Materiais + gorjeta",
    cond_matsFixed = "Materiais + preço fixo", cond_ownMats = "Meus próprios materiais", cond_negotiable = "Materiais a combinar",
    cond_free = "De graça com seus materiais", cond_leveling = "Upando a profissão", cond_custom = "Oferta personalizada",
    offerCustomConditions = "Suas próprias condições", offerFee = "Preço", offerFeeEach = "por criação", offerFeeTotal = "por pedido (preço total)",
    offerFeeNote = "O ForeverCraft só registra sua oferta. Ouro e itens nunca são transferidos automaticamente.",
    offerRecipes = "Receitas especiais", offerRecipesCount = "%d receitas escolhidas", offerRecipesNone = "Nenhuma receita escolhida",
    offerChooseRecipes = "Escolher receitas…", offerClearRecipes = "Limpar", offerRecipeSearch = "Buscar receita",
    offerRecipeAllCategories = "Todas as categorias",
    offerRecipeBound = "Vinculado ao pegar – não dá para entregar", offerRecipeLoading = "Carregando dados dos itens…",
    offerRecipeCooldown = "Recarga: faltam %s", offerRecipeService = "Serviço", offerRecipesDone = "Pronto",
    offerProfile = "Perfil", offerProfileDefault = "Oferta padrão", offerProfileSave = "Salvar", offerProfileNew = "Novo perfil",
    offerProfileDelete = "Excluir", offerProfileName = "Nome do perfil", offerProfileDeleteConfirm = "Excluir o perfil \"%s\"?",
    offerTemplate = "Modelo", template_casual = "Descontraído e simpático", template_short = "Curto e direto",
    offerManageTemplates = "Meus modelos…", offerLanguage = "Idioma da mensagem", offerLanguageAuto = "Igual ao cliente",
    offerChannel = "Canal", channel_trade = "Comércio", channel_guild = "Guilda", channel_general = "Geral",
    offerOptions = "Opções",
    opt_showSkill = "Mostrar nível da profissão", opt_showMax = "Mostrar nível máximo",
    opt_professionLinks = "Inserir links de profissão (se o cliente suportar)", opt_recipeLinks = "Inserir links de itens e receitas",
    opt_highlightRecipes = "Destacar as receitas escolhidas", opt_showConditions = "Mostrar as condições", opt_askWhisper = "Pedir um sussurro",
    offerPreview = "Prévia (editável)",
    offerEmpty = "Escolha pelo menos uma profissão ou receita.", offerRegenerate = "Recriar o texto", offerPost = "Publicar",
    offerPostWait = "Aguarde (%d s)", offerConfirm = "Enviar esta oferta para \"%s\"?\n\n%s", offerSent = "Enviado para %s.",
    offerConfirmed = "A mensagem apareceu no chat.",
    offerNotConfirmed = "A mensagem não apareceu no chat. Talvez o cliente a tenha bloqueado.",
    offerTradeUnavailable = "O canal de Comércio não está disponível aqui agora. Vá para uma cidade ou escolha outro canal.",
    offerChannelUnavailable = "O canal \"%s\" não está disponível agora.", offerGuildUnavailable = "Você não está em uma guilda.",
    offerCooldownActive = "Aguarde mais %d segundos (proteção local contra mensagens repetidas).",
    offerQuickOff = "A publicação rápida está desligada nas opções.", offerNoLast = "Ainda não há uma última oferta usada.",
    templatesTitle = "ForeverCraft · Meus modelos de mensagem", templateNew = "Novo", templateDuplicate = "Duplicar",
    templateSave = "Salvar", templateDelete = "Excluir", templateName = "Nome", templateDefaultName = "Meu modelo",
    templatePlaceholders = "Variáveis: {berufe} {berufe_skill} {rezepte} {konditionen} {verguetung} {charakter} {berufslinks} {rezeptlinks} (ou {professions} {recipes} …). Linhas com variável vazia são omitidas.",
    templateNone = "Nenhum modelo próprio ainda.",
    settingsOffers = "Ofertas de profissão", settingsOffersMessage = "Mensagem", settingsOffersPosting = "Publicação",
    settingsOffersDetail = "Cada publicação exige um clique. A espera é uma proteção local e não substitui as regras do servidor.",
    settingsOfferQuick = "Publicação rápida com Shift + clique esquerdo", settingsOfferPreview = "Mostrar prévia da mensagem",
    settingsOfferConfirm = "Confirmar antes de enviar", settingsOfferCooldown = "Espera: %d s",
    settingsOfferCondition = "Condições padrão: %s", settingsOfferChannel = "Canal padrão: %s",
    settingsOfferLanguage = "Idioma da mensagem: %s", settingsOfferTemplate = "Modelo padrão: %s",
    settingsOfferOpen = "Abrir janela de oferta", settingsOfferTemplates = "Gerenciar meus modelos",
}

texts.ruRU = {
    offerButton = "Предложить крафт",
    offerTooltip = "Предложите свои профессии в канале «Торговля». Вы сами решаете, какие профессии предлагать и на каких условиях делать вещи.",
    offerTooltipClicks = "ЛКМ: открыть окно объявления\nПКМ: сохранённые профили\nShift + ЛКМ: сразу опубликовать последнее объявление",
    offerQuickDisabled = "Быстрая публикация выключена (включается в настройках).",
    offerTitle = "ForeverCraft · Предложить крафт",
    offerProfessions = "Предлагаемые профессии", offerGathering = "Профессия сбора",
    offerNoProfessions = "У этого персонажа не найдено профессий.",
    offerPerProfession = "Условия для каждой профессии", offerConditions = "Условия",
    cond_mats = "Ваши реагенты", cond_matsTip = "Реагенты + чаевые по желанию", cond_matsPaid = "Реагенты + чаевые",
    cond_matsFixed = "Реагенты + фиксированная цена", cond_ownMats = "Мои реагенты", cond_negotiable = "Реагенты по договорённости",
    cond_free = "Бесплатно из ваших реагентов", cond_leveling = "Качаю профессию", cond_custom = "Свои условия",
    offerCustomConditions = "Ваши условия", offerFee = "Цена", offerFeeEach = "за крафт", offerFeeTotal = "за заказ (общая цена)",
    offerFeeNote = "ForeverCraft только записывает ваше предложение. Золото и предметы никогда не передаются автоматически.",
    offerRecipes = "Особые рецепты", offerRecipesCount = "Выбрано рецептов: %d", offerRecipesNone = "Рецепты не выбраны",
    offerChooseRecipes = "Выбрать рецепты…", offerClearRecipes = "Очистить", offerRecipeSearch = "Поиск рецепта",
    offerRecipeAllCategories = "Все категории",
    offerRecipeBound = "Становится персональным при получении – передать нельзя", offerRecipeLoading = "Загрузка данных предметов…",
    offerRecipeCooldown = "Восстановление: осталось %s", offerRecipeService = "Услуга", offerRecipesDone = "Готово",
    offerProfile = "Профиль", offerProfileDefault = "Обычное объявление", offerProfileSave = "Сохранить", offerProfileNew = "Новый профиль",
    offerProfileDelete = "Удалить", offerProfileName = "Название профиля", offerProfileDeleteConfirm = "Удалить профиль «%s»?",
    offerTemplate = "Шаблон", template_casual = "Дружелюбно", template_short = "Коротко и по делу",
    offerManageTemplates = "Свои шаблоны…", offerLanguage = "Язык сообщения", offerLanguageAuto = "Как у клиента",
    offerChannel = "Канал", channel_trade = "Торговля", channel_guild = "Гильдия", channel_general = "Общий",
    offerOptions = "Параметры",
    opt_showSkill = "Показывать уровень профессии", opt_showMax = "Показывать максимальный уровень",
    opt_professionLinks = "Вставлять ссылки на профессии (если клиент поддерживает)", opt_recipeLinks = "Вставлять ссылки на предметы и рецепты",
    opt_highlightRecipes = "Выделять выбранные рецепты", opt_showConditions = "Показывать условия", opt_askWhisper = "Просить написать в личку",
    offerPreview = "Предпросмотр (можно править)",
    offerEmpty = "Выберите хотя бы одну профессию или рецепт.", offerRegenerate = "Собрать текст заново", offerPost = "Опубликовать",
    offerPostWait = "Ждите (%d с)", offerConfirm = "Отправить объявление в «%s»?\n\n%s", offerSent = "Отправлено в %s.",
    offerConfirmed = "Сообщение появилось в чате.",
    offerNotConfirmed = "Сообщение не появилось в чате. Возможно, клиент его заблокировал.",
    offerTradeUnavailable = "Канал «Торговля» здесь сейчас недоступен. Отправляйтесь в город или выберите другой канал.",
    offerChannelUnavailable = "Канал «%s» сейчас недоступен.", offerGuildUnavailable = "Вы не состоите в гильдии.",
    offerCooldownActive = "Подождите ещё %d с (локальная защита от повторной отправки).",
    offerQuickOff = "Быстрая публикация выключена в настройках.", offerNoLast = "Ещё нет последнего объявления.",
    templatesTitle = "ForeverCraft · Свои шаблоны сообщений", templateNew = "Новый", templateDuplicate = "Копировать",
    templateSave = "Сохранить", templateDelete = "Удалить", templateName = "Название", templateDefaultName = "Мой шаблон",
    templatePlaceholders = "Подстановки: {berufe} {berufe_skill} {rezepte} {konditionen} {verguetung} {charakter} {berufslinks} {rezeptlinks} (или {professions} {recipes} …). Строки с пустой подстановкой пропускаются.",
    templateNone = "Своих шаблонов пока нет.",
    settingsOffers = "Объявления о крафте", settingsOffersMessage = "Сообщение", settingsOffersPosting = "Публикация",
    settingsOffersDetail = "Каждая публикация требует клика. Задержка – локальная защита и не заменяет правила сервера.",
    settingsOfferQuick = "Быстрая публикация через Shift + ЛКМ", settingsOfferPreview = "Показывать предпросмотр",
    settingsOfferConfirm = "Подтверждать перед отправкой", settingsOfferCooldown = "Задержка: %d с",
    settingsOfferCondition = "Условия по умолчанию: %s", settingsOfferChannel = "Канал по умолчанию: %s",
    settingsOfferLanguage = "Язык сообщения: %s", settingsOfferTemplate = "Шаблон по умолчанию: %s",
    settingsOfferOpen = "Открыть окно объявления", settingsOfferTemplates = "Управлять своими шаблонами",
}

texts.koKR = {
    offerButton = "제작 광고",
    offerTooltip = "거래 채널에 제작 전문기술을 광고합니다. 어떤 전문기술을 어떤 조건으로 제작할지 직접 정할 수 있습니다.",
    offerTooltipClicks = "왼쪽 클릭: 광고 창 열기\n오른쪽 클릭: 저장된 광고 프로필\nShift + 왼쪽 클릭: 마지막 광고 바로 게시",
    offerQuickDisabled = "빠른 게시가 꺼져 있습니다(설정에서 켤 수 있음).",
    offerTitle = "ForeverCraft · 제작 광고",
    offerProfessions = "광고할 전문기술", offerGathering = "채집 전문기술",
    offerNoProfessions = "이 캐릭터에서 전문기술을 찾지 못했습니다.",
    offerPerProfession = "전문기술별 조건 설정", offerConditions = "조건",
    cond_mats = "재료 지참", cond_matsTip = "재료 + 자율 팁", cond_matsPaid = "재료 + 팁",
    cond_matsFixed = "재료 + 고정 비용", cond_ownMats = "제 재료로 제작", cond_negotiable = "재료 협의",
    cond_free = "재료 지참 시 무료", cond_leveling = "숙련도 올리는 중", cond_custom = "직접 입력",
    offerCustomConditions = "직접 정한 조건", offerFee = "비용", offerFeeEach = "제작당", offerFeeTotal = "주문당(총액)",
    offerFeeNote = "ForeverCraft는 광고 내용만 기록합니다. 골드나 아이템은 절대 자동으로 옮겨지지 않습니다.",
    offerRecipes = "특별 제작법", offerRecipesCount = "제작법 %d개 선택됨", offerRecipesNone = "선택한 제작법 없음",
    offerChooseRecipes = "제작법 선택…", offerClearRecipes = "비우기", offerRecipeSearch = "제작법 검색",
    offerRecipeAllCategories = "모든 분류",
    offerRecipeBound = "획득 시 귀속 – 건네줄 수 없음", offerRecipeLoading = "아이템 정보를 불러오는 중…",
    offerRecipeCooldown = "재사용 대기시간: %s 남음", offerRecipeService = "서비스", offerRecipesDone = "완료",
    offerProfile = "프로필", offerProfileDefault = "기본 광고", offerProfileSave = "저장", offerProfileNew = "새 프로필",
    offerProfileDelete = "삭제", offerProfileName = "프로필 이름", offerProfileDeleteConfirm = "\"%s\" 프로필을 삭제할까요?",
    offerTemplate = "문구", template_casual = "친근하게", template_short = "짧고 간단하게",
    offerManageTemplates = "내 문구…", offerLanguage = "메시지 언어", offerLanguageAuto = "클라이언트와 같게",
    offerChannel = "채널", channel_trade = "거래", channel_guild = "길드", channel_general = "일반",
    offerOptions = "옵션",
    opt_showSkill = "숙련도 표시", opt_showMax = "최대 숙련도 표시",
    opt_professionLinks = "전문기술 링크 넣기(클라이언트가 지원하는 경우)", opt_recipeLinks = "아이템·제작법 링크 넣기",
    opt_highlightRecipes = "선택한 제작법 강조", opt_showConditions = "조건 표시", opt_askWhisper = "귓속말 요청",
    offerPreview = "미리보기(수정 가능)",
    offerEmpty = "전문기술이나 제작법을 하나 이상 고르세요.", offerRegenerate = "문구 다시 만들기", offerPost = "게시",
    offerPostWait = "대기(%d초)", offerConfirm = "이 광고를 \"%s\"에 보낼까요?\n\n%s", offerSent = "%s에 보냈습니다.",
    offerConfirmed = "메시지가 채팅에 표시되었습니다.",
    offerNotConfirmed = "메시지가 채팅에 표시되지 않았습니다. 클라이언트가 막았을 수 있습니다.",
    offerTradeUnavailable = "지금 이곳에서는 거래 채널을 쓸 수 없습니다. 도시로 가거나 다른 채널을 고르세요.",
    offerChannelUnavailable = "\"%s\" 채널을 지금 쓸 수 없습니다.", offerGuildUnavailable = "길드에 가입되어 있지 않습니다.",
    offerCooldownActive = "%d초 더 기다려 주세요(중복 게시 방지용 로컬 대기).",
    offerQuickOff = "설정에서 빠른 게시가 꺼져 있습니다.", offerNoLast = "아직 마지막으로 쓴 광고가 없습니다.",
    templatesTitle = "ForeverCraft · 내 메시지 문구", templateNew = "새로 만들기", templateDuplicate = "복제",
    templateSave = "저장", templateDelete = "삭제", templateName = "이름", templateDefaultName = "내 문구",
    templatePlaceholders = "치환어: {berufe} {berufe_skill} {rezepte} {konditionen} {verguetung} {charakter} {berufslinks} {rezeptlinks} (또는 {professions} {recipes} …). 치환어가 비면 그 줄은 빠집니다.",
    templateNone = "아직 내 문구가 없습니다.",
    settingsOffers = "제작 광고", settingsOffersMessage = "메시지", settingsOffersPosting = "게시",
    settingsOffersDetail = "모든 게시는 클릭이 필요합니다. 대기 시간은 로컬 보호 장치일 뿐 서버 채팅 규칙을 대신하지 않습니다.",
    settingsOfferQuick = "Shift + 왼쪽 클릭으로 빠른 게시", settingsOfferPreview = "메시지 미리보기 표시",
    settingsOfferConfirm = "보내기 전에 확인", settingsOfferCooldown = "대기 시간: %d초",
    settingsOfferCondition = "기본 조건: %s", settingsOfferChannel = "기본 채널: %s",
    settingsOfferLanguage = "메시지 언어: %s", settingsOfferTemplate = "기본 문구: %s",
    settingsOfferOpen = "광고 창 열기", settingsOfferTemplates = "내 문구 관리",
}

texts.zhTW = {
    offerButton = "提供代工",
    offerTooltip = "在交易頻道宣傳你的製作專業。你可以自行決定要提供哪些專業，以及在什麼條件下幫忙製作。",
    offerTooltipClicks = "左鍵：開啟宣傳視窗\n右鍵：已儲存的宣傳設定檔\nShift + 左鍵：直接發佈上次的宣傳",
    offerQuickDisabled = "快速發佈已關閉（可在設定中開啟）。",
    offerTitle = "ForeverCraft · 提供代工",
    offerProfessions = "提供的專業", offerGathering = "採集專業",
    offerNoProfessions = "這個角色沒有找到任何專業。",
    offerPerProfession = "每個專業分別設定條件", offerConditions = "條件",
    cond_mats = "自備材料", cond_matsTip = "材料＋小費隨意", cond_matsPaid = "材料＋小費",
    cond_matsFixed = "材料＋固定費用", cond_ownMats = "用我的材料", cond_negotiable = "材料可商量",
    cond_free = "自備材料免費", cond_leveling = "正在練專業", cond_custom = "自訂條件",
    offerCustomConditions = "自訂條件", offerFee = "費用", offerFeeEach = "每次製作", offerFeeTotal = "每筆訂單（總價）",
    offerFeeNote = "ForeverCraft 只會記錄你的宣傳內容，絕不會自動轉移金幣或物品。",
    offerRecipes = "特別配方", offerRecipesCount = "已選 %d 個配方", offerRecipesNone = "尚未選擇配方",
    offerChooseRecipes = "選擇配方…", offerClearRecipes = "清空", offerRecipeSearch = "搜尋配方",
    offerRecipeAllCategories = "所有分類",
    offerRecipeBound = "拾取後綁定－無法交給他人", offerRecipeLoading = "正在載入物品資料…",
    offerRecipeCooldown = "冷卻：還剩 %s", offerRecipeService = "服務", offerRecipesDone = "完成",
    offerProfile = "設定檔", offerProfileDefault = "標準宣傳", offerProfileSave = "儲存", offerProfileNew = "新增設定檔",
    offerProfileDelete = "刪除", offerProfileName = "設定檔名稱", offerProfileDeleteConfirm = "要刪除設定檔「%s」嗎？",
    offerTemplate = "範本", template_casual = "輕鬆友善", template_short = "簡短直接",
    offerManageTemplates = "自訂範本…", offerLanguage = "訊息語言", offerLanguageAuto = "與用戶端相同",
    offerChannel = "頻道", channel_trade = "交易", channel_guild = "公會", channel_general = "綜合",
    offerOptions = "選項",
    opt_showSkill = "顯示專業技能等級", opt_showMax = "顯示最高技能等級",
    opt_professionLinks = "插入專業連結（若用戶端支援）", opt_recipeLinks = "插入物品與配方連結",
    opt_highlightRecipes = "突顯選擇的配方", opt_showConditions = "顯示條件", opt_askWhisper = "請對方密語",
    offerPreview = "預覽（可編輯）",
    offerEmpty = "請至少選擇一個專業或配方。", offerRegenerate = "重新產生文字", offerPost = "發佈",
    offerPostWait = "等待（%d 秒）", offerConfirm = "要將這則宣傳發送到「%s」嗎？\n\n%s", offerSent = "已發送到 %s。",
    offerConfirmed = "訊息已出現在聊天中。",
    offerNotConfirmed = "訊息沒有出現在聊天中，可能被用戶端擋下了。",
    offerTradeUnavailable = "這裡目前無法使用交易頻道。請前往城市，或選擇其他聊天頻道。",
    offerChannelUnavailable = "頻道「%s」目前無法使用。", offerGuildUnavailable = "你目前不在任何公會中。",
    offerCooldownActive = "請再等 %d 秒（防止重複發佈的本機保護）。",
    offerQuickOff = "設定中已關閉快速發佈。", offerNoLast = "目前還沒有上次使用的宣傳。",
    templatesTitle = "ForeverCraft · 自訂訊息範本", templateNew = "新增", templateDuplicate = "複製",
    templateSave = "儲存", templateDelete = "刪除", templateName = "名稱", templateDefaultName = "我的範本",
    templatePlaceholders = "替換文字：{berufe} {berufe_skill} {rezepte} {konditionen} {verguetung} {charakter} {berufslinks} {rezeptlinks}（或 {professions} {recipes} …）。替換後為空的整行會被省略。",
    templateNone = "還沒有自訂範本。",
    settingsOffers = "代工宣傳", settingsOffersMessage = "訊息", settingsOffersPosting = "發佈",
    settingsOffersDetail = "每次發佈都需要點擊。等待時間只是本機保護，不能取代伺服器的聊天規則。",
    settingsOfferQuick = "Shift + 左鍵快速發佈", settingsOfferPreview = "顯示訊息預覽",
    settingsOfferConfirm = "發送前確認", settingsOfferCooldown = "等待時間：%d 秒",
    settingsOfferCondition = "預設條件：%s", settingsOfferChannel = "預設頻道：%s",
    settingsOfferLanguage = "訊息語言：%s", settingsOfferTemplate = "預設範本：%s",
    settingsOfferOpen = "開啟宣傳視窗", settingsOfferTemplates = "管理自訂範本",
}


-- Added with the multi-profession recipe picker (0.1.136).
texts.enUS.offerAllProfessions = "All professions"
texts.enUS.offerRecipesTitle = "ForeverCraft · Choose recipes"
texts.enUS.offerRecipesClear = "Clear selection"
texts.enUS.offerRecipesApply = "Use selection"
texts.enUS.offerRecipesSelectedCount = "%d selected"
texts.enUS.offerRecipesNotScanned = "Your %s recipes have not been recorded yet. Open the %s window once so ForeverCraft can read the recipes you know."
texts.enUS.offerRecipeOther = "Other"
texts.enUS.offerRecipesNoMatch = "No recipe matches the search."
texts.enUS.offerRecipesNoProfession = "First tick a crafting profession in the offer window."
texts.enUS.offerLengthBoth = "Visible %d characters · technical %d / %d bytes"
texts.enUS.offerShorten = "Suggest a shorter version"
texts.enUS.offerShortenFailed = "Even the shortest wording is too long. Pick fewer recipes or shorten the text yourself."
texts.enUS.offerShortened = "Shortened: %s"
texts.enUS.shorten_shortTemplate = "short template"
texts.enUS.shorten_noMax = "without maximum skill"
texts.enUS.shorten_recipeNames = "recipe names instead of links"
texts.enUS.shorten_professionNames = "profession names instead of links"
texts.enUS.shorten_noWhisper = "without whisper request"
texts.enUS.shorten_noSkill = "without skill"
texts.deDE.offerAllProfessions = "Alle Berufe"
texts.deDE.offerRecipesTitle = "ForeverCraft · Rezepte auswählen"
texts.deDE.offerRecipesClear = "Auswahl leeren"
texts.deDE.offerRecipesApply = "Auswahl übernehmen"
texts.deDE.offerRecipesSelectedCount = "%d ausgewählt"
texts.deDE.offerRecipesNotScanned = "Deine Rezepte für %s wurden noch nicht erfasst. Öffne einmal das Fenster für %s, damit ForeverCraft deine bekannten Rezepte einlesen kann."
texts.deDE.offerRecipeOther = "Sonstiges"
texts.deDE.offerRecipesNoMatch = "Kein Rezept passt zur Suche."
texts.deDE.offerRecipesNoProfession = "Wähle im Angebotsfenster zuerst einen Herstellungsberuf aus."
texts.deDE.offerLengthBoth = "Sichtbar %d Zeichen · technisch %d / %d Byte"
texts.deDE.offerShorten = "Kürzere Fassung vorschlagen"
texts.deDE.offerShortenFailed = "Auch die kürzeste Fassung ist zu lang. Wähle weniger Rezepte oder kürze den Text selbst."
texts.deDE.offerShortened = "Gekürzt: %s"
texts.deDE.shorten_shortTemplate = "kurze Vorlage"
texts.deDE.shorten_noMax = "ohne Maximalfertigkeit"
texts.deDE.shorten_recipeNames = "Rezeptnamen statt Links"
texts.deDE.shorten_professionNames = "Berufsnamen statt Links"
texts.deDE.shorten_noWhisper = "ohne Bitte um Flüstern"
texts.deDE.shorten_noSkill = "ohne Fertigkeit"
texts.frFR.offerAllProfessions = "Tous les métiers"
texts.frFR.offerRecipesTitle = "ForeverCraft · Choisir des recettes"
texts.frFR.offerRecipesClear = "Vider la sélection"
texts.frFR.offerRecipesApply = "Valider la sélection"
texts.frFR.offerRecipesSelectedCount = "%d choisie(s)"
texts.frFR.offerRecipesNotScanned = "Vos recettes de %s n'ont pas encore été enregistrées. Ouvrez une fois la fenêtre %s pour que ForeverCraft lise les recettes que vous connaissez."
texts.frFR.offerRecipeOther = "Autres"
texts.frFR.offerRecipesNoMatch = "Aucune recette ne correspond à la recherche."
texts.frFR.offerRecipesNoProfession = "Cochez d'abord un métier d'artisanat dans la fenêtre d'annonce."
texts.frFR.offerLengthBoth = "Visible %d caractères · technique %d / %d octets"
texts.frFR.offerShorten = "Proposer une version plus courte"
texts.frFR.offerShortenFailed = "Même la version la plus courte est trop longue. Choisissez moins de recettes ou raccourcissez le texte."
texts.frFR.offerShortened = "Raccourci : %s"
texts.frFR.shorten_shortTemplate = "modèle court"
texts.frFR.shorten_noMax = "sans niveau maximum"
texts.frFR.shorten_recipeNames = "noms de recettes au lieu des liens"
texts.frFR.shorten_professionNames = "noms de métiers au lieu des liens"
texts.frFR.shorten_noWhisper = "sans demande de MP"
texts.frFR.shorten_noSkill = "sans niveau"
texts.esES.offerAllProfessions = "Todas las profesiones"
texts.esES.offerRecipesTitle = "ForeverCraft · Elegir recetas"
texts.esES.offerRecipesClear = "Vaciar selección"
texts.esES.offerRecipesApply = "Usar selección"
texts.esES.offerRecipesSelectedCount = "%d elegidas"
texts.esES.offerRecipesNotScanned = "Tus recetas de %s aún no se han registrado. Abre una vez la ventana de %s para que ForeverCraft lea las recetas que conoces."
texts.esES.offerRecipeOther = "Otros"
texts.esES.offerRecipesNoMatch = "Ninguna receta coincide con la búsqueda."
texts.esES.offerRecipesNoProfession = "Primero marca una profesión de fabricación en la ventana de oferta."
texts.esES.offerLengthBoth = "Visible %d caracteres · técnico %d / %d bytes"
texts.esES.offerShorten = "Proponer una versión más corta"
texts.esES.offerShortenFailed = "Incluso la versión más corta es demasiado larga. Elige menos recetas o acorta el texto."
texts.esES.offerShortened = "Acortado: %s"
texts.esES.shorten_shortTemplate = "plantilla corta"
texts.esES.shorten_noMax = "sin nivel máximo"
texts.esES.shorten_recipeNames = "nombres de recetas en vez de enlaces"
texts.esES.shorten_professionNames = "nombres de profesiones en vez de enlaces"
texts.esES.shorten_noWhisper = "sin pedir susurro"
texts.esES.shorten_noSkill = "sin nivel"
texts.ptBR.offerAllProfessions = "Todas as profissões"
texts.ptBR.offerRecipesTitle = "ForeverCraft · Escolher receitas"
texts.ptBR.offerRecipesClear = "Limpar seleção"
texts.ptBR.offerRecipesApply = "Usar seleção"
texts.ptBR.offerRecipesSelectedCount = "%d escolhidas"
texts.ptBR.offerRecipesNotScanned = "Suas receitas de %s ainda não foram registradas. Abra a janela de %s uma vez para o ForeverCraft ler as receitas que você conhece."
texts.ptBR.offerRecipeOther = "Outros"
texts.ptBR.offerRecipesNoMatch = "Nenhuma receita corresponde à busca."
texts.ptBR.offerRecipesNoProfession = "Primeiro marque uma profissão de criação na janela de oferta."
texts.ptBR.offerLengthBoth = "Visível %d caracteres · técnico %d / %d bytes"
texts.ptBR.offerShorten = "Sugerir versão mais curta"
texts.ptBR.offerShortenFailed = "Mesmo a versão mais curta é longa demais. Escolha menos receitas ou encurte o texto."
texts.ptBR.offerShortened = "Encurtado: %s"
texts.ptBR.shorten_shortTemplate = "modelo curto"
texts.ptBR.shorten_noMax = "sem nível máximo"
texts.ptBR.shorten_recipeNames = "nomes de receitas em vez de links"
texts.ptBR.shorten_professionNames = "nomes de profissões em vez de links"
texts.ptBR.shorten_noWhisper = "sem pedir sussurro"
texts.ptBR.shorten_noSkill = "sem nível"
texts.ruRU.offerAllProfessions = "Все профессии"
texts.ruRU.offerRecipesTitle = "ForeverCraft · Выбор рецептов"
texts.ruRU.offerRecipesClear = "Очистить выбор"
texts.ruRU.offerRecipesApply = "Применить выбор"
texts.ruRU.offerRecipesSelectedCount = "выбрано: %d"
texts.ruRU.offerRecipesNotScanned = "Рецепты профессии «%s» ещё не записаны. Откройте окно профессии «%s» один раз, чтобы ForeverCraft прочитал известные вам рецепты."
texts.ruRU.offerRecipeOther = "Прочее"
texts.ruRU.offerRecipesNoMatch = "Ни один рецепт не подходит под поиск."
texts.ruRU.offerRecipesNoProfession = "Сначала отметьте профессию в окне объявления."
texts.ruRU.offerLengthBoth = "Видно %d символов · технически %d / %d байт"
texts.ruRU.offerShorten = "Предложить короче"
texts.ruRU.offerShortenFailed = "Даже самый короткий вариант слишком длинный. Выберите меньше рецептов или сократите текст."
texts.ruRU.offerShortened = "Сокращено: %s"
texts.ruRU.shorten_shortTemplate = "короткий шаблон"
texts.ruRU.shorten_noMax = "без максимального уровня"
texts.ruRU.shorten_recipeNames = "названия рецептов вместо ссылок"
texts.ruRU.shorten_professionNames = "названия профессий вместо ссылок"
texts.ruRU.shorten_noWhisper = "без просьбы написать"
texts.ruRU.shorten_noSkill = "без уровня"
texts.koKR.offerAllProfessions = "모든 전문기술"
texts.koKR.offerRecipesTitle = "ForeverCraft · 제작법 선택"
texts.koKR.offerRecipesClear = "선택 비우기"
texts.koKR.offerRecipesApply = "선택 적용"
texts.koKR.offerRecipesSelectedCount = "%d개 선택"
texts.koKR.offerRecipesNotScanned = "%s 제작법이 아직 기록되지 않았습니다. ForeverCraft가 알고 있는 제작법을 읽을 수 있도록 %s 창을 한 번 열어 주세요."
texts.koKR.offerRecipeOther = "기타"
texts.koKR.offerRecipesNoMatch = "검색과 일치하는 제작법이 없습니다."
texts.koKR.offerRecipesNoProfession = "먼저 광고 창에서 제작 전문기술을 선택하세요."
texts.koKR.offerLengthBoth = "보이는 글자 %d · 실제 %d / %d 바이트"
texts.koKR.offerShorten = "더 짧게 제안"
texts.koKR.offerShortenFailed = "가장 짧은 문구도 너무 깁니다. 제작법을 줄이거나 직접 줄여 주세요."
texts.koKR.offerShortened = "줄임: %s"
texts.koKR.shorten_shortTemplate = "짧은 문구"
texts.koKR.shorten_noMax = "최대 숙련도 없이"
texts.koKR.shorten_recipeNames = "링크 대신 제작법 이름"
texts.koKR.shorten_professionNames = "링크 대신 전문기술 이름"
texts.koKR.shorten_noWhisper = "귓속말 요청 없이"
texts.koKR.shorten_noSkill = "숙련도 없이"
texts.zhTW.offerAllProfessions = "所有專業"
texts.zhTW.offerRecipesTitle = "ForeverCraft · 選擇配方"
texts.zhTW.offerRecipesClear = "清空選擇"
texts.zhTW.offerRecipesApply = "套用選擇"
texts.zhTW.offerRecipesSelectedCount = "已選 %d 個"
texts.zhTW.offerRecipesNotScanned = "你的%s配方尚未記錄。請開啟一次%s視窗，讓 ForeverCraft 讀取你已學會的配方。"
texts.zhTW.offerRecipeOther = "其他"
texts.zhTW.offerRecipesNoMatch = "沒有符合搜尋的配方。"
texts.zhTW.offerRecipesNoProfession = "請先在宣傳視窗中勾選一個製作專業。"
texts.zhTW.offerLengthBoth = "可見 %d 字元 · 實際 %d / %d 位元組"
texts.zhTW.offerShorten = "建議較短版本"
texts.zhTW.offerShortenFailed = "最短的版本仍然太長。請少選一些配方或自行縮短文字。"
texts.zhTW.offerShortened = "已縮短：%s"
texts.zhTW.shorten_shortTemplate = "簡短範本"
texts.zhTW.shorten_noMax = "不顯示最高等級"
texts.zhTW.shorten_recipeNames = "以配方名稱取代連結"
texts.zhTW.shorten_professionNames = "以專業名稱取代連結"
texts.zhTW.shorten_noWhisper = "不請對方密語"
texts.zhTW.shorten_noSkill = "不顯示技能等級"


-- Long offers in two messages (0.1.136).
texts.enUS.offerSentParts = "Sent to %s (%d messages)."
texts.enUS.offerSplitImpossible = "Too long even for two messages. Shorten the text or pick fewer recipes – links are never cut."
texts.enUS.offerLengthParts = "%s · %d messages"
texts.enUS.offerSplitInfo = "Too long for one message – it will be sent as %d messages in one click."
texts.deDE.offerSentParts = "Gesendet an %s (%d Nachrichten)."
texts.deDE.offerSplitImpossible = "Auch für zwei Nachrichten zu lang. Kürze den Text oder wähle weniger Rezepte – Links werden nie zerschnitten."
texts.deDE.offerLengthParts = "%s · %d Nachrichten"
texts.deDE.offerSplitInfo = "Zu lang für eine Nachricht – wird mit einem Klick als %d Nachrichten gesendet."
texts.frFR.offerSentParts = "Envoyé dans %s (%d messages)."
texts.frFR.offerSplitImpossible = "Trop long même pour deux messages. Raccourcissez le texte ou choisissez moins de recettes – les liens ne sont jamais coupés."
texts.frFR.offerLengthParts = "%s · %d messages"
texts.frFR.offerSplitInfo = "Trop long pour un message – il sera envoyé en %d messages en un clic."
texts.esES.offerSentParts = "Enviado a %s (%d mensajes)."
texts.esES.offerSplitImpossible = "Demasiado largo incluso para dos mensajes. Acorta el texto o elige menos recetas; los enlaces nunca se cortan."
texts.esES.offerLengthParts = "%s · %d mensajes"
texts.esES.offerSplitInfo = "Demasiado largo para un mensaje: se enviará como %d mensajes con un clic."
texts.ptBR.offerSentParts = "Enviado para %s (%d mensagens)."
texts.ptBR.offerSplitImpossible = "Longo demais mesmo para duas mensagens. Encurte o texto ou escolha menos receitas – links nunca são cortados."
texts.ptBR.offerLengthParts = "%s · %d mensagens"
texts.ptBR.offerSplitInfo = "Longo demais para uma mensagem – será enviada como %d mensagens com um clique."
texts.ruRU.offerSentParts = "Отправлено в %s (сообщений: %d)."
texts.ruRU.offerSplitImpossible = "Слишком длинно даже для двух сообщений. Сократите текст или выберите меньше рецептов – ссылки никогда не обрезаются."
texts.ruRU.offerLengthParts = "%s · сообщений: %d"
texts.ruRU.offerSplitInfo = "Слишком длинно для одного сообщения – будет отправлено %d сообщениями одним кликом."
texts.koKR.offerSentParts = "%s에 보냈습니다(메시지 %d개)."
texts.koKR.offerSplitImpossible = "메시지 두 개로도 너무 깁니다. 문구를 줄이거나 제작법을 덜 고르세요. 링크는 잘리지 않습니다."
texts.koKR.offerLengthParts = "%s · 메시지 %d개"
texts.koKR.offerSplitInfo = "메시지 하나로는 너무 깁니다. 한 번 클릭으로 메시지 %d개로 보냅니다."
texts.zhTW.offerSentParts = "已發送到 %s（%d 則訊息）。"
texts.zhTW.offerSplitImpossible = "即使分成兩則訊息仍然太長。請縮短文字或少選一些配方——連結絕不會被截斷。"
texts.zhTW.offerLengthParts = "%s · %d 則訊息"
texts.zhTW.offerSplitInfo = "一則訊息放不下——點一次就會分成 %d 則訊息發送。"


-- Offer buttons in the crafting log (0.1.136).
texts.enUS.offerConfigure = "Configure offer"
texts.enUS.offerConfigureSub = "Professions, conditions and text"
texts.enUS.offerStateTrade = "Post the offer in trade chat"
texts.enUS.offerStateChannel = "Post the offer: %s"
texts.enUS.offerStateSetup = "Configure an offer first"
texts.enUS.offerStateWait = "Available again in %s"
texts.enUS.offerStateNoTrade = "Trade chat not available right now"
texts.enUS.offerStateNoChannel = "Chat channel not available right now"
texts.enUS.offerStatePosted = "Offer posted"
texts.enUS.offerMenuProfile = "Profile: %s"
texts.enUS.offerMenuPreview = "Message preview"
texts.enUS.offerMenuPost = "Post offer"
texts.enUS.offerTipProfile = "Profile"
texts.enUS.offerTipChannel = "Channel"
texts.enUS.offerTipClicks = "Left-click: post the saved offer · Right-click: more options"
texts.deDE.offerConfigure = "Angebot konfigurieren"
texts.deDE.offerConfigureSub = "Berufe, Konditionen und Text"
texts.deDE.offerStateTrade = "Angebot im Handelschat posten"
texts.deDE.offerStateChannel = "Angebot posten: %s"
texts.deDE.offerStateSetup = "Zuerst ein Angebot konfigurieren"
texts.deDE.offerStateWait = "Erneut verfügbar in %s"
texts.deDE.offerStateNoTrade = "Handelschat derzeit nicht verfügbar"
texts.deDE.offerStateNoChannel = "Chatkanal derzeit nicht verfügbar"
texts.deDE.offerStatePosted = "Angebot veröffentlicht"
texts.deDE.offerMenuProfile = "Profil: %s"
texts.deDE.offerMenuPreview = "Nachrichtenvorschau"
texts.deDE.offerMenuPost = "Angebot veröffentlichen"
texts.deDE.offerTipProfile = "Profil"
texts.deDE.offerTipChannel = "Kanal"
texts.deDE.offerTipClicks = "Linksklick: gespeichertes Angebot posten · Rechtsklick: weitere Optionen"
texts.frFR.offerConfigure = "Configurer l’offre"
texts.frFR.offerConfigureSub = "Métiers, conditions et texte"
texts.frFR.offerStateTrade = "Publier l’offre dans le canal Commerce"
texts.frFR.offerStateChannel = "Publier l’offre : %s"
texts.frFR.offerStateSetup = "Configurez d’abord une offre"
texts.frFR.offerStateWait = "De nouveau disponible dans %s"
texts.frFR.offerStateNoTrade = "Canal Commerce indisponible pour le moment"
texts.frFR.offerStateNoChannel = "Canal de discussion indisponible pour le moment"
texts.frFR.offerStatePosted = "Offre publiée"
texts.frFR.offerMenuProfile = "Profil : %s"
texts.frFR.offerMenuPreview = "Aperçu du message"
texts.frFR.offerMenuPost = "Publier l’offre"
texts.frFR.offerTipProfile = "Profil"
texts.frFR.offerTipChannel = "Canal"
texts.frFR.offerTipClicks = "Clic gauche : publier l’offre enregistrée · Clic droit : autres options"
texts.esES.offerConfigure = "Configurar oferta"
texts.esES.offerConfigureSub = "Profesiones, condiciones y texto"
texts.esES.offerStateTrade = "Publicar la oferta en el canal de Comercio"
texts.esES.offerStateChannel = "Publicar la oferta: %s"
texts.esES.offerStateSetup = "Configura primero una oferta"
texts.esES.offerStateWait = "Disponible de nuevo en %s"
texts.esES.offerStateNoTrade = "El canal de Comercio no está disponible ahora"
texts.esES.offerStateNoChannel = "El canal de chat no está disponible ahora"
texts.esES.offerStatePosted = "Oferta publicada"
texts.esES.offerMenuProfile = "Perfil: %s"
texts.esES.offerMenuPreview = "Vista previa del mensaje"
texts.esES.offerMenuPost = "Publicar oferta"
texts.esES.offerTipProfile = "Perfil"
texts.esES.offerTipChannel = "Canal"
texts.esES.offerTipClicks = "Clic izquierdo: publicar la oferta guardada · Clic derecho: más opciones"
texts.ptBR.offerConfigure = "Configurar oferta"
texts.ptBR.offerConfigureSub = "Profissões, condições e texto"
texts.ptBR.offerStateTrade = "Publicar a oferta no canal de Comércio"
texts.ptBR.offerStateChannel = "Publicar a oferta: %s"
texts.ptBR.offerStateSetup = "Configure uma oferta primeiro"
texts.ptBR.offerStateWait = "Disponível novamente em %s"
texts.ptBR.offerStateNoTrade = "Canal de Comércio indisponível no momento"
texts.ptBR.offerStateNoChannel = "Canal de bate-papo indisponível no momento"
texts.ptBR.offerStatePosted = "Oferta publicada"
texts.ptBR.offerMenuProfile = "Perfil: %s"
texts.ptBR.offerMenuPreview = "Prévia da mensagem"
texts.ptBR.offerMenuPost = "Publicar oferta"
texts.ptBR.offerTipProfile = "Perfil"
texts.ptBR.offerTipChannel = "Canal"
texts.ptBR.offerTipClicks = "Clique esquerdo: publicar a oferta salva · Clique direito: mais opções"
texts.ruRU.offerConfigure = "Настроить предложение"
texts.ruRU.offerConfigureSub = "Профессии, условия и текст"
texts.ruRU.offerStateTrade = "Опубликовать в канале «Торговля»"
texts.ruRU.offerStateChannel = "Опубликовать: %s"
texts.ruRU.offerStateSetup = "Сначала настройте предложение"
texts.ruRU.offerStateWait = "Снова доступно через %s"
texts.ruRU.offerStateNoTrade = "Канал «Торговля» сейчас недоступен"
texts.ruRU.offerStateNoChannel = "Канал чата сейчас недоступен"
texts.ruRU.offerStatePosted = "Предложение опубликовано"
texts.ruRU.offerMenuProfile = "Профиль: %s"
texts.ruRU.offerMenuPreview = "Предпросмотр сообщения"
texts.ruRU.offerMenuPost = "Опубликовать предложение"
texts.ruRU.offerTipProfile = "Профиль"
texts.ruRU.offerTipChannel = "Канал"
texts.ruRU.offerTipClicks = "ЛКМ: опубликовать сохранённое предложение · ПКМ: другие действия"
texts.koKR.offerConfigure = "제작 제안 설정"
texts.koKR.offerConfigureSub = "전문 기술, 조건 및 문구"
texts.koKR.offerStateTrade = "거래 채널에 제안 올리기"
texts.koKR.offerStateChannel = "제안 올리기: %s"
texts.koKR.offerStateSetup = "먼저 제안을 설정하세요"
texts.koKR.offerStateWait = "%s 후 다시 사용 가능"
texts.koKR.offerStateNoTrade = "지금은 거래 채널을 사용할 수 없습니다"
texts.koKR.offerStateNoChannel = "지금은 대화 채널을 사용할 수 없습니다"
texts.koKR.offerStatePosted = "제안을 올렸습니다"
texts.koKR.offerMenuProfile = "프로필: %s"
texts.koKR.offerMenuPreview = "메시지 미리 보기"
texts.koKR.offerMenuPost = "제안 올리기"
texts.koKR.offerTipProfile = "프로필"
texts.koKR.offerTipChannel = "채널"
texts.koKR.offerTipClicks = "왼쪽 클릭: 저장된 제안 올리기 · 오른쪽 클릭: 추가 옵션"
texts.zhTW.offerConfigure = "設定製作服務"
texts.zhTW.offerConfigureSub = "專業技能、條件與文字"
texts.zhTW.offerStateTrade = "在交易頻道發布"
texts.zhTW.offerStateChannel = "發布：%s"
texts.zhTW.offerStateSetup = "請先設定製作服務"
texts.zhTW.offerStateWait = "%s 後可再次發布"
texts.zhTW.offerStateNoTrade = "目前無法使用交易頻道"
texts.zhTW.offerStateNoChannel = "目前無法使用聊天頻道"
texts.zhTW.offerStatePosted = "已發布"
texts.zhTW.offerMenuProfile = "設定檔：%s"
texts.zhTW.offerMenuPreview = "訊息預覽"
texts.zhTW.offerMenuPost = "發布製作服務"
texts.zhTW.offerTipProfile = "設定檔"
texts.zhTW.offerTipChannel = "頻道"
texts.zhTW.offerTipClicks = "左鍵：發布已儲存的內容 · 右鍵：更多選項"

for locale, entries in pairs(texts) do
    local catalog = addon.strings[locale]
    if catalog then
        for key, value in pairs(entries) do catalog[key] = value end
    end
end
