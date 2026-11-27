local _, addon = ...
-- Crafting offers for the trade chat: conditions, natural message templates in every
-- supported message language, placeholders for own templates, chat-safe text, channel
-- lookup and the local cooldown. Pure logic without frames (OfferUI.lua builds the window).
-- ForeverCraft never sends anything by itself: every message is posted from a click.
local offers = {}
addon.offers = offers

offers.MAX_LENGTH = 255
offers.cooldowns = { 60, 120, 180, 300 }
offers.conditions = { "mats", "matsTip", "matsPaid", "matsFixed", "ownMats", "negotiable", "free", "leveling", "custom" }
offers.templates = { "casual", "short" }
offers.languages = { "auto", "deDE", "enUS", "frFR", "esES", "ptBR", "ruRU", "koKR", "zhTW" }
-- Gathering professions are listed but never preselected as a crafting service.
offers.gathering = { [182] = true, [186] = true, [393] = true, [356] = true }

-- Profession names per message language (skill line IDs as returned by GetProfessionInfo).
local NAMES = {
    [171] = { enUS = "Alchemy", deDE = "Alchemie", frFR = "Alchimie", esES = "Alquimia", ptBR = "Alquimia",
        ruRU = "Алхимия", koKR = "연금술", zhTW = "鍊金術" },
    [164] = { enUS = "Blacksmithing", deDE = "Schmiedekunst", frFR = "Forge", esES = "Herrería", ptBR = "Ferraria",
        ruRU = "Кузнечное дело", koKR = "대장기술", zhTW = "鍛造" },
    [333] = { enUS = "Enchanting", deDE = "Verzauberkunst", frFR = "Enchantement", esES = "Encantamiento",
        ptBR = "Encantamento", ruRU = "Наложение чар", koKR = "마법부여", zhTW = "附魔" },
    [202] = { enUS = "Engineering", deDE = "Ingenieurskunst", frFR = "Ingénierie", esES = "Ingeniería",
        ptBR = "Engenharia", ruRU = "Инженерное дело", koKR = "기계공학", zhTW = "工程學" },
    [165] = { enUS = "Leatherworking", deDE = "Lederverarbeitung", frFR = "Travail du cuir", esES = "Peletería",
        ptBR = "Couraria", ruRU = "Кожевничество", koKR = "가죽세공", zhTW = "製皮" },
    [197] = { enUS = "Tailoring", deDE = "Schneiderei", frFR = "Couture", esES = "Sastrería", ptBR = "Alfaiataria",
        ruRU = "Портняжное дело", koKR = "재봉술", zhTW = "裁縫" },
    [185] = { enUS = "Cooking", deDE = "Kochkunst", frFR = "Cuisine", esES = "Cocina", ptBR = "Culinária",
        ruRU = "Кулинария", koKR = "요리", zhTW = "烹飪" },
    [129] = { enUS = "First Aid", deDE = "Erste Hilfe", frFR = "Secourisme", esES = "Primeros auxilios",
        ptBR = "Primeiros Socorros", ruRU = "Первая помощь", koKR = "응급치료", zhTW = "急救" },
    [755] = { enUS = "Jewelcrafting", deDE = "Juwelenschleifen", frFR = "Joaillerie", esES = "Joyería",
        ptBR = "Joalheria", ruRU = "Ювелирное дело", koKR = "보석세공", zhTW = "珠寶設計" },
    [182] = { enUS = "Herbalism", deDE = "Kräuterkunde", frFR = "Herboristerie", esES = "Herboristería",
        ptBR = "Herborismo", ruRU = "Травничество", koKR = "약초채집", zhTW = "草藥學" },
    [186] = { enUS = "Mining", deDE = "Bergbau", frFR = "Minage", esES = "Minería", ptBR = "Mineração",
        ruRU = "Горное дело", koKR = "채광", zhTW = "採礦" },
    [393] = { enUS = "Skinning", deDE = "Kürschnerei", frFR = "Dépeçage", esES = "Desuello", ptBR = "Esfolamento",
        ruRU = "Снятие шкур", koKR = "무두질", zhTW = "剝皮" },
    [356] = { enUS = "Fishing", deDE = "Angeln", frFR = "Pêche", esES = "Pesca", ptBR = "Pesca",
        ruRU = "Рыбная ловля", koKR = "낚시", zhTW = "釣魚" },
}
offers.professionNames = NAMES

-- Message phrases. {P} professions or recipes, {F} fee, {C} own conditions. `whisper` is
-- appended unless the sentence already asks for contact (noWhisper).
local P = {}
offers.phrases = P
P.deDE = {
    sep = ", ", lastSep = " und ", coins = { "g", "s", "k" }, skill = "%s (%d)", skillMax = "%s (%d/%d)",
    feeEach = "%s pro Herstellung", feeTotal = "%s pro Auftrag",
    casual = {
        mats = "Hey zusammen! Biete {P} gegen eure Mats an.",
        matsTip = "Hey zusammen! Biete {P} gegen eure Mats an. Über ein kleines Trinkgeld freue ich mich natürlich.",
        matsPaid = "Hey zusammen! Biete {P} gegen eure Mats und Trinkgeld an.",
        matsFixed = "Hey zusammen! Biete {P} gegen eure Mats und {F} an.",
        ownMats = "Biete {P} auch mit eigenen Mats an. Schreibt mir einfach, was ihr braucht, dann können wir den Preis besprechen.",
        negotiable = "Hey zusammen! Biete {P} an, Mats nach Absprache.",
        free = "Falls jemand etwas von {P} braucht: Ich stelle euch gerne kostenlos etwas gegen eure Mats her!",
        leveling = "Levele gerade {P}. Falls jemand etwas braucht, crafte ich gerne kostenlos gegen eure Mats!",
        custom = "Hey zusammen! Biete {P} an: {C}.",
        plain = "Hey zusammen! Biete {P} an.",
        whisper = "Bei Interesse einfach anwhispern!",
    },
    short = {
        mats = "Biete {P} gegen Mats.", matsTip = "Biete {P} gegen Mats, Trinkgeld freiwillig.",
        matsPaid = "Biete {P} gegen Mats + Trinkgeld.", matsFixed = "Biete {P} gegen Mats + {F}.",
        ownMats = "Biete {P} mit eigenen Mats, Preis nach Absprache.", negotiable = "Biete {P}, Mats nach Absprache.",
        free = "Biete {P} kostenlos gegen Mats.", leveling = "Levele {P}, crafte kostenlos gegen Mats.",
        custom = "Biete {P}: {C}.", plain = "Biete {P}.", whisper = "Bei Interesse whispern!",
    },
    extra = {
        mats = "Außerdem {P} gegen eure Mats.", matsTip = "Außerdem {P} gegen Mats, Trinkgeld freiwillig.",
        matsPaid = "Außerdem {P} gegen Mats + Trinkgeld.", matsFixed = "Außerdem {P} gegen Mats + {F}.",
        ownMats = "Außerdem {P} auch mit eigenen Mats.", negotiable = "Außerdem {P}, Mats nach Absprache.",
        free = "Außerdem {P} kostenlos gegen Mats.", leveling = "Außerdem {P} zum Leveln, kostenlos gegen Mats.",
        custom = "Außerdem {P}: {C}.", plain = "Außerdem {P}.",
    },
    recipesAlso = "Kann unter anderem {R} herstellen.",
    condition = {
        mats = "gegen eure Mats", matsTip = "gegen eure Mats, Trinkgeld freiwillig", matsPaid = "gegen eure Mats und Trinkgeld",
        matsFixed = "gegen eure Mats und {F}", ownMats = "mit eigenen Mats, Preis nach Absprache",
        negotiable = "Mats nach Absprache", free = "kostenlos gegen eure Mats", leveling = "kostenlos gegen eure Mats",
        custom = "{C}",
    },
}
P.enUS = {
    sep = ", ", lastSep = " and ", coins = { "g", "s", "c" }, skill = "%s (%d)", skillMax = "%s (%d/%d)",
    feeEach = "%s per craft", feeTotal = "%s per order",
    casual = {
        mats = "Hey all! Offering {P} with your mats.",
        matsTip = "Hey all! Offering {P} with your mats. Tips are appreciated but not required.",
        matsPaid = "Hey all! Offering {P} with your mats plus a tip.",
        matsFixed = "Hey all! Offering {P} with your mats for {F}.",
        ownMats = "Offering {P} with my own mats too. Just tell me what you need and we'll work out a price.",
        negotiable = "Hey all! Offering {P}, mats by arrangement.",
        free = "If anyone needs something from {P}: happy to craft it for free with your mats!",
        leveling = "Leveling {P} right now. If you need anything, I'll craft it for free with your mats!",
        custom = "Hey all! Offering {P}: {C}.", plain = "Hey all! Offering {P}.",
        whisper = "Just whisper me!",
    },
    short = {
        mats = "Crafting {P}, your mats.", matsTip = "Crafting {P}, your mats, tips optional.",
        matsPaid = "Crafting {P}, your mats + tip.", matsFixed = "Crafting {P}, your mats + {F}.",
        ownMats = "Crafting {P} with my own mats, price on request.", negotiable = "Crafting {P}, mats negotiable.",
        free = "Crafting {P} for free, your mats.", leveling = "Leveling {P}, crafting for free with your mats.",
        custom = "Crafting {P}: {C}.", plain = "Crafting {P}.", whisper = "Whisper me!",
    },
    extra = {
        mats = "Also {P} with your mats.", matsTip = "Also {P} with your mats, tips optional.",
        matsPaid = "Also {P} with your mats + tip.", matsFixed = "Also {P} with your mats + {F}.",
        ownMats = "Also {P} with my own mats.", negotiable = "Also {P}, mats negotiable.",
        free = "Also {P} for free with your mats.", leveling = "Also leveling {P}, free with your mats.",
        custom = "Also {P}: {C}.", plain = "Also {P}.",
    },
    recipesAlso = "I can also make {R}, among other things.",
    condition = {
        mats = "with your mats", matsTip = "with your mats, tips optional", matsPaid = "with your mats plus a tip",
        matsFixed = "with your mats for {F}", ownMats = "with my own mats, price on request", negotiable = "mats by arrangement",
        free = "for free with your mats", leveling = "for free with your mats", custom = "{C}",
    },
}
P.frFR = {
    sep = ", ", lastSep = " et ", coins = { "po", "pa", "pc" }, skill = "%s (%d)", skillMax = "%s (%d/%d)",
    feeEach = "%s par craft", feeTotal = "%s par commande",
    casual = {
        mats = "Salut tout le monde ! Je propose {P} avec vos compos.",
        matsTip = "Salut tout le monde ! Je propose {P} avec vos compos, pourboire libre.",
        matsPaid = "Salut tout le monde ! Je propose {P} avec vos compos + un pourboire.",
        matsFixed = "Salut tout le monde ! Je propose {P} avec vos compos pour {F}.",
        ownMats = "Je propose aussi {P} avec mes propres compos. Dites-moi ce qu'il vous faut et on voit pour le prix.",
        negotiable = "Salut tout le monde ! Je propose {P}, compos à voir ensemble.",
        free = "Si quelqu'un a besoin de quelque chose en {P} : je crafte gratuitement avec vos compos !",
        leveling = "Je monte {P} en ce moment. Besoin de quelque chose ? Je crafte gratuitement avec vos compos !",
        custom = "Salut tout le monde ! Je propose {P} : {C}.", plain = "Salut tout le monde ! Je propose {P}.",
        whisper = "N'hésitez pas à me MP !",
    },
    short = {
        mats = "Craft {P}, vos compos.", matsTip = "Craft {P}, vos compos, pourboire libre.",
        matsPaid = "Craft {P}, vos compos + pourboire.", matsFixed = "Craft {P}, vos compos + {F}.",
        ownMats = "Craft {P} avec mes compos, prix à voir.", negotiable = "Craft {P}, compos à voir.",
        free = "Craft {P} gratuit, vos compos.", leveling = "Je monte {P}, craft gratuit avec vos compos.",
        custom = "Craft {P} : {C}.", plain = "Craft {P}.", whisper = "MP !",
    },
    extra = {
        mats = "Aussi {P} avec vos compos.", matsTip = "Aussi {P} avec vos compos, pourboire libre.",
        matsPaid = "Aussi {P} avec vos compos + pourboire.", matsFixed = "Aussi {P} avec vos compos + {F}.",
        ownMats = "Aussi {P} avec mes propres compos.", negotiable = "Aussi {P}, compos à voir.",
        free = "Aussi {P} gratuit avec vos compos.", leveling = "Je monte aussi {P}, gratuit avec vos compos.",
        custom = "Aussi {P} : {C}.", plain = "Aussi {P}.",
    },
    recipesAlso = "Je peux aussi faire {R}.",
    condition = {
        mats = "avec vos compos", matsTip = "avec vos compos, pourboire libre", matsPaid = "avec vos compos + pourboire",
        matsFixed = "avec vos compos pour {F}", ownMats = "avec mes compos, prix à voir", negotiable = "compos à voir ensemble",
        free = "gratuitement avec vos compos", leveling = "gratuitement avec vos compos", custom = "{C}",
    },
}
P.esES = {
    sep = ", ", lastSep = " y ", coins = { "o", "p", "c" }, skill = "%s (%d)", skillMax = "%s (%d/%d)",
    feeEach = "%s por fabricación", feeTotal = "%s por encargo",
    casual = {
        mats = "¡Hola a todos! Ofrezco {P} con vuestros materiales.",
        matsTip = "¡Hola a todos! Ofrezco {P} con vuestros materiales, la propina es voluntaria.",
        matsPaid = "¡Hola a todos! Ofrezco {P} con vuestros materiales y una propina.",
        matsFixed = "¡Hola a todos! Ofrezco {P} con vuestros materiales por {F}.",
        ownMats = "También ofrezco {P} con mis propios materiales. Decidme qué necesitáis y hablamos del precio.",
        negotiable = "¡Hola a todos! Ofrezco {P}, materiales a convenir.",
        free = "Si alguien necesita algo de {P}: ¡os lo hago gratis con vuestros materiales!",
        leveling = "Estoy subiendo {P}. Si necesitáis algo, ¡os lo hago gratis con vuestros materiales!",
        custom = "¡Hola a todos! Ofrezco {P}: {C}.", plain = "¡Hola a todos! Ofrezco {P}.",
        whisper = "¡Susurradme si os interesa!",
    },
    short = {
        mats = "Hago {P}, vuestros mats.", matsTip = "Hago {P}, vuestros mats, propina voluntaria.",
        matsPaid = "Hago {P}, vuestros mats + propina.", matsFixed = "Hago {P}, vuestros mats + {F}.",
        ownMats = "Hago {P} con mis mats, precio a convenir.", negotiable = "Hago {P}, mats a convenir.",
        free = "Hago {P} gratis, vuestros mats.", leveling = "Subiendo {P}, lo hago gratis con vuestros mats.",
        custom = "Hago {P}: {C}.", plain = "Hago {P}.", whisper = "¡Susurrad!",
    },
    extra = {
        mats = "También {P} con vuestros materiales.", matsTip = "También {P} con vuestros mats, propina voluntaria.",
        matsPaid = "También {P} con vuestros mats + propina.", matsFixed = "También {P} con vuestros mats + {F}.",
        ownMats = "También {P} con mis propios materiales.", negotiable = "También {P}, materiales a convenir.",
        free = "También {P} gratis con vuestros materiales.", leveling = "También subiendo {P}, gratis con vuestros mats.",
        custom = "También {P}: {C}.", plain = "También {P}.",
    },
    recipesAlso = "También puedo hacer {R}.",
    condition = {
        mats = "con vuestros materiales", matsTip = "con vuestros materiales, propina voluntaria",
        matsPaid = "con vuestros materiales y propina", matsFixed = "con vuestros materiales por {F}",
        ownMats = "con mis materiales, precio a convenir", negotiable = "materiales a convenir",
        free = "gratis con vuestros materiales", leveling = "gratis con vuestros materiales", custom = "{C}",
    },
}
P.ptBR = {
    sep = ", ", lastSep = " e ", coins = { "o", "p", "c" }, skill = "%s (%d)", skillMax = "%s (%d/%d)",
    feeEach = "%s por criação", feeTotal = "%s por pedido",
    casual = {
        mats = "Olá, pessoal! Ofereço {P} com os seus materiais.",
        matsTip = "Olá, pessoal! Ofereço {P} com os seus materiais, gorjeta opcional.",
        matsPaid = "Olá, pessoal! Ofereço {P} com os seus materiais e uma gorjeta.",
        matsFixed = "Olá, pessoal! Ofereço {P} com os seus materiais por {F}.",
        ownMats = "Também ofereço {P} com meus próprios materiais. Me digam o que precisam e combinamos o preço.",
        negotiable = "Olá, pessoal! Ofereço {P}, materiais a combinar.",
        free = "Se alguém precisar de algo de {P}: faço de graça com os seus materiais!",
        leveling = "Estou upando {P}. Se precisarem de algo, faço de graça com os seus materiais!",
        custom = "Olá, pessoal! Ofereço {P}: {C}.", plain = "Olá, pessoal! Ofereço {P}.",
        whisper = "É só me sussurrar!",
    },
    short = {
        mats = "Faço {P}, seus mats.", matsTip = "Faço {P}, seus mats, gorjeta opcional.",
        matsPaid = "Faço {P}, seus mats + gorjeta.", matsFixed = "Faço {P}, seus mats + {F}.",
        ownMats = "Faço {P} com meus mats, preço a combinar.", negotiable = "Faço {P}, mats a combinar.",
        free = "Faço {P} de graça, seus mats.", leveling = "Upando {P}, faço de graça com seus mats.",
        custom = "Faço {P}: {C}.", plain = "Faço {P}.", whisper = "Sussurra!",
    },
    extra = {
        mats = "Também {P} com seus materiais.", matsTip = "Também {P} com seus mats, gorjeta opcional.",
        matsPaid = "Também {P} com seus mats + gorjeta.", matsFixed = "Também {P} com seus mats + {F}.",
        ownMats = "Também {P} com meus próprios materiais.", negotiable = "Também {P}, materiais a combinar.",
        free = "Também {P} de graça com seus materiais.", leveling = "Também upando {P}, de graça com seus mats.",
        custom = "Também {P}: {C}.", plain = "Também {P}.",
    },
    recipesAlso = "Também faço {R}.",
    condition = {
        mats = "com os seus materiais", matsTip = "com os seus materiais, gorjeta opcional",
        matsPaid = "com os seus materiais e gorjeta", matsFixed = "com os seus materiais por {F}",
        ownMats = "com meus materiais, preço a combinar", negotiable = "materiais a combinar",
        free = "de graça com os seus materiais", leveling = "de graça com os seus materiais", custom = "{C}",
    },
}
-- Russian avoids declined profession names by listing them after a colon or in brackets.
P.ruRU = {
    sep = ", ", lastSep = " и ", coins = { "з", "с", "м" }, skill = "%s (%d)", skillMax = "%s (%d/%d)",
    feeEach = "%s за крафт", feeTotal = "%s за заказ",
    casual = {
        mats = "Всем привет! Предлагаю крафт: {P}. Реагенты ваши.",
        matsTip = "Всем привет! Предлагаю крафт: {P}. Реагенты ваши, чаевые по желанию.",
        matsPaid = "Всем привет! Предлагаю крафт: {P}. Реагенты ваши + чаевые.",
        matsFixed = "Всем привет! Предлагаю крафт: {P}. Реагенты ваши + {F}.",
        ownMats = "Предлагаю крафт: {P}, могу и из своих реагентов. Напишите, что нужно, и договоримся о цене.",
        negotiable = "Всем привет! Предлагаю крафт: {P}. Реагенты по договорённости.",
        free = "Нужен крафт? {P} — сделаю бесплатно из ваших реагентов!",
        leveling = "Сейчас качаю: {P}. Если что-то нужно, сделаю бесплатно из ваших реагентов!",
        custom = "Всем привет! Предлагаю крафт: {P}. {C}.", plain = "Всем привет! Предлагаю крафт: {P}.",
        whisper = "Пишите в личку!",
    },
    short = {
        mats = "Крафт: {P}. Ваши реаги.", matsTip = "Крафт: {P}. Ваши реаги, чаевые по желанию.",
        matsPaid = "Крафт: {P}. Ваши реаги + чаевые.", matsFixed = "Крафт: {P}. Ваши реаги + {F}.",
        ownMats = "Крафт: {P} из своих реагов, цена договорная.", negotiable = "Крафт: {P}. Реаги по договорённости.",
        free = "Крафт: {P}. Бесплатно, ваши реаги.", leveling = "Качаю профу ({P}), крафчу бесплатно из ваших реагов.",
        custom = "Крафт: {P}. {C}.", plain = "Крафт: {P}.", whisper = "Пишите в ЛС!",
    },
    extra = {
        mats = "Также: {P}, реагенты ваши.", matsTip = "Также: {P}, реагенты ваши, чаевые по желанию.",
        matsPaid = "Также: {P}, реагенты ваши + чаевые.", matsFixed = "Также: {P}, реагенты ваши + {F}.",
        ownMats = "Также: {P}, можно из моих реагентов.", negotiable = "Также: {P}, реагенты по договорённости.",
        free = "Также: {P}, бесплатно из ваших реагентов.", leveling = "Также качаю: {P}, бесплатно из ваших реагентов.",
        custom = "Также: {P}. {C}.", plain = "Также: {P}.",
    },
    recipesAlso = "Также могу сделать: {R}.",
    condition = {
        mats = "реагенты ваши", matsTip = "реагенты ваши, чаевые по желанию", matsPaid = "реагенты ваши + чаевые",
        matsFixed = "реагенты ваши + {F}", ownMats = "из моих реагентов, цена договорная",
        negotiable = "реагенты по договорённости", free = "бесплатно из ваших реагентов",
        leveling = "бесплатно из ваших реагентов", custom = "{C}",
    },
}
P.koKR = {
    sep = ", ", lastSep = ", ", coins = { "골", "실", "코" }, skill = "%s (%d)", skillMax = "%s (%d/%d)",
    feeEach = "제작당 %s", feeTotal = "주문당 %s",
    casual = {
        mats = "안녕하세요! {P} 제작해 드립니다. 재료는 지참해 주세요.",
        matsTip = "안녕하세요! {P} 제작해 드립니다. 재료 지참, 팁은 자유입니다.",
        matsPaid = "안녕하세요! {P} 제작해 드립니다. 재료 지참 + 팁 부탁드려요.",
        matsFixed = "안녕하세요! {P} 제작해 드립니다. 재료 지참 + {F}.",
        ownMats = "{P} 제 재료로도 제작 가능합니다. 필요한 걸 말씀해 주시면 가격은 협의해요.",
        negotiable = "안녕하세요! {P} 제작해 드립니다. 재료는 협의 가능합니다.",
        free = "{P} 필요하신 분 계시면 재료만 주시면 무료로 만들어 드려요!",
        leveling = "{P} 숙련도 올리는 중입니다. 필요하신 게 있으면 재료만 주시면 무료로 만들어 드려요!",
        custom = "안녕하세요! {P} 제작해 드립니다: {C}.", plain = "안녕하세요! {P} 제작해 드립니다.",
        whisper = "귓속말 주세요!",
    },
    short = {
        mats = "{P} 제작, 재료 지참.", matsTip = "{P} 제작, 재료 지참, 팁 자유.", matsPaid = "{P} 제작, 재료 지참 + 팁.",
        matsFixed = "{P} 제작, 재료 지참 + {F}.", ownMats = "{P} 제 재료로 제작, 가격 협의.",
        negotiable = "{P} 제작, 재료 협의.", free = "{P} 무료 제작, 재료 지참.", leveling = "{P} 숙련 중, 재료 주시면 무료 제작.",
        custom = "{P} 제작: {C}.", plain = "{P} 제작.", whisper = "귓 주세요!",
    },
    extra = {
        mats = "{P}도 제작해 드려요(재료 지참).", matsTip = "{P}도 제작해 드려요(재료 지참, 팁 자유).",
        matsPaid = "{P}도 제작해 드려요(재료 지참 + 팁).", matsFixed = "{P}도 제작해 드려요(재료 지참 + {F}).",
        ownMats = "{P}도 제 재료로 제작 가능해요.", negotiable = "{P}도 제작해 드려요(재료 협의).",
        free = "{P}도 재료만 주시면 무료예요.", leveling = "{P}도 숙련 중이라 무료로 만들어 드려요.",
        custom = "{P}도 제작해 드려요: {C}.", plain = "{P}도 제작해 드려요.",
    },
    recipesAlso = "{R}도 만들 수 있어요.",
    condition = {
        mats = "재료 지참", matsTip = "재료 지참, 팁 자유", matsPaid = "재료 지참 + 팁", matsFixed = "재료 지참 + {F}",
        ownMats = "제 재료로 제작, 가격 협의", negotiable = "재료 협의", free = "재료 지참 시 무료",
        leveling = "재료 지참 시 무료", custom = "{C}",
    },
}
P.zhTW = {
    sep = "、", lastSep = "、", coins = { "金", "銀", "銅" }, skill = "%s (%d)", skillMax = "%s (%d/%d)",
    feeEach = "每次製作 %s", feeTotal = "每筆訂單 %s",
    casual = {
        mats = "大家好！提供 {P} 代工，請自備材料。",
        matsTip = "大家好！提供 {P} 代工，自備材料，小費隨意。",
        matsPaid = "大家好！提供 {P} 代工，自備材料＋小費。",
        matsFixed = "大家好！提供 {P} 代工，自備材料＋{F}。",
        ownMats = "{P} 也可以用我自己的材料製作，需要什麼跟我說，價格再談。",
        negotiable = "大家好！提供 {P} 代工，材料可再商量。",
        free = "有人需要 {P} 的東西嗎？自備材料免費幫做！",
        leveling = "正在練 {P}，需要什麼的話自備材料免費幫做！",
        custom = "大家好！提供 {P} 代工：{C}。", plain = "大家好！提供 {P} 代工。",
        whisper = "有需要請密我！",
    },
    short = {
        mats = "{P} 代工，自備材料。", matsTip = "{P} 代工，自備材料，小費隨意。", matsPaid = "{P} 代工，自備材料＋小費。",
        matsFixed = "{P} 代工，自備材料＋{F}。", ownMats = "{P} 代工，可用我的材料，價格另議。",
        negotiable = "{P} 代工，材料可商量。", free = "{P} 免費代工，自備材料。", leveling = "練 {P} 中，自備材料免費代工。",
        custom = "{P} 代工：{C}。", plain = "{P} 代工。", whisper = "請密！",
    },
    extra = {
        mats = "另外 {P} 也可代工（自備材料）。", matsTip = "另外 {P} 也可代工（自備材料，小費隨意）。",
        matsPaid = "另外 {P} 也可代工（自備材料＋小費）。", matsFixed = "另外 {P} 也可代工（自備材料＋{F}）。",
        ownMats = "另外 {P} 也可用我的材料製作。", negotiable = "另外 {P} 也可代工（材料可商量）。",
        free = "另外 {P} 自備材料免費代工。", leveling = "另外正在練 {P}，自備材料免費代工。",
        custom = "另外 {P}：{C}。", plain = "另外 {P} 也可代工。",
    },
    recipesAlso = "也可以製作 {R}。",
    condition = {
        mats = "自備材料", matsTip = "自備材料，小費隨意", matsPaid = "自備材料＋小費", matsFixed = "自備材料＋{F}",
        ownMats = "可用我的材料，價格另議", negotiable = "材料可商量", free = "自備材料免費", leveling = "自備材料免費",
        custom = "{C}",
    },
}
P.enGB, P.esMX = P.enUS, P.esES
local NO_WHISPER = { ownMats = true }

function offers.messageLanguage(choice, clientLocale)
    local language = (not choice or choice == "auto") and clientLocale or choice
    if language == "enGB" then language = "enUS" elseif language == "esMX" then language = "esES" end
    return P[language] and language or "enUS"
end

-- Localised profession name in the message language; the client name is the fallback.
function offers.professionName(skillLine, language, clientName, clientLocale)
    local alias = { enGB = "enUS", esMX = "esES" }
    if language == (alias[clientLocale] or clientLocale) and clientName then return clientName end
    local names = NAMES[skillLine]
    return names and names[language] or clientName or tostring(skillLine)
end

-- Money for chat (coin textures are not allowed in chat): "2g 50s" in the message language.
function offers.moneyText(copper, language)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local coins = (P[language] or P.enUS).coins
    local values, parts = { math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100 }, {}
    for index = 1, 3 do
        if values[index] > 0 then parts[#parts + 1] = values[index] .. coins[index] end
    end
    if #parts == 0 then parts[1] = "0" .. coins[3] end
    return table.concat(parts, " ")
end

function offers.copper(gold, silver, copper)
    gold, silver, copper = tonumber(gold) or 0, tonumber(silver) or 0, tonumber(copper) or 0
    if gold < 0 or silver < 0 or copper < 0 then return nil end
    return math.floor(gold) * 10000 + math.floor(silver) * 100 + math.floor(copper)
end

function offers.list(items, language)
    local phrase = P[language] or P.enUS
    if #items == 0 then return "" end
    if #items == 1 then return items[1] end
    return table.concat(items, phrase.sep, 1, #items - 1) .. phrase.lastSep .. items[#items]
end

local function feeText(config, language)
    local phrase = P[language] or P.enUS
    local money = offers.moneyText(config.fee or 0, language)
    return (config.feeMode == "total" and phrase.feeTotal or phrase.feeEach):format(money)
end

local function fill(sentence, values)
    return (sentence:gsub("{(%u)}", function(key) return values[key] or "" end))
end

-- Chat-safe text: one line, no stray escape sequences; valid item/spell links stay intact.
function offers.sanitize(text)
    text = tostring(text or ""):gsub("[\r\n]+", " ")
    local links = {}
    text = text:gsub("|c%x%x%x%x%x%x%x%x|H.-|h.-|h|r", function(link)
        links[#links + 1] = link
        return "\001" .. #links .. "\001"
    end)
    text = text:gsub("|", "")
    text = text:gsub("\001(%d+)\001", function(index) return links[tonumber(index)] end)
    text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

-- Builds the message from a configuration and the player's data.
-- data.professions: { { id, name, skill, max, link } } (only the selected ones)
-- data.recipes: { { name, link } }, data.character, data.clientLocale
-- config: condition, perProfession, conditions, fee, feeMode, customText, template, language,
-- options { showSkill, showMax, professionLinks, recipeLinks, highlightRecipes, showConditions, askWhisper }
function offers.build(config, data)
    local language = offers.messageLanguage(config.language, data.clientLocale)
    local phrase = P[language]
    local options = config.options or {}
    local function professionLabel(entry, withSkill)
        local name = offers.professionName(entry.id, language, entry.name, data.clientLocale)
        if options.professionLinks and entry.link then name = entry.link end
        if withSkill and entry.skill then
            if options.showMax and entry.max then return phrase.skillMax:format(name, entry.skill, entry.max) end
            return phrase.skill:format(name, entry.skill)
        end
        return name
    end
    local recipeNames = {}
    for _, recipe in ipairs(data.recipes or {}) do
        recipeNames[#recipeNames + 1] = (options.recipeLinks and recipe.link) or recipe.name
    end
    local fee = feeText(config, language)
    local custom = offers.sanitize(config.customText or "")

    -- Own template: placeholders only, nothing is translated or rewritten.
    if config.template and config.template:match("^custom:") then
        local template = data.customTemplate or ""
        local plain, skilled, links = {}, {}, {}
        for _, entry in ipairs(data.professions or {}) do
            plain[#plain + 1] = offers.professionName(entry.id, language, entry.name, data.clientLocale)
            skilled[#skilled + 1] = professionLabel(entry, true)
            links[#links + 1] = entry.link or plain[#plain]
        end
        local recipeLinks = {}
        for _, recipe in ipairs(data.recipes or {}) do recipeLinks[#recipeLinks + 1] = recipe.link or recipe.name end
        local condition = config.condition or "mats"
        local values = {
            berufe = offers.list(plain, language), professions = offers.list(plain, language),
            berufe_skill = offers.list(skilled, language), professions_skill = offers.list(skilled, language),
            rezepte = offers.list(recipeNames, language), recipes = offers.list(recipeNames, language),
            konditionen = fill(phrase.condition[condition] or "", { F = fee, C = custom }),
            verguetung = (condition == "matsFixed" or (config.fee or 0) > 0) and fee or "",
            charakter = data.character or "", character = data.character or "",
            berufslinks = offers.list(links, language), professionlinks = offers.list(links, language),
            rezeptlinks = offers.list(recipeLinks, language), recipelinks = offers.list(recipeLinks, language),
        }
        values.conditions, values.fee = values.konditionen, values.verguetung
        -- A line whose placeholder has no content is dropped, so no half sentences remain.
        local lines = {}
        for line in (template .. "\n"):gmatch("(.-)\n") do
            local empty = false
            local result = line:gsub("{([%w_]+)}", function(key)
                local value = values[key:lower()]
                if value == nil then return "" end
                if value == "" then empty = true return "" end
                return value
            end)
            if not empty and result:match("%S") then lines[#lines + 1] = result end
        end
        return offers.sanitize(table.concat(lines, " "))
    end

    local style = phrase[config.template == "short" and "short" or "casual"]
    local sentences = {}
    -- Group professions by condition (same condition for all unless set per profession).
    local groups, order = {}, {}
    for _, entry in ipairs(data.professions or {}) do
        local condition = (config.perProfession and config.conditions and config.conditions[entry.id]) or config.condition or "mats"
        if not options.showConditions then condition = "plain" end
        if not groups[condition] then
            groups[condition] = {}
            order[#order + 1] = condition
        end
        table.insert(groups[condition], professionLabel(entry, options.showSkill))
    end
    local recipesText = offers.list(recipeNames, language)
    local mainCondition = order[1]
    if not mainCondition then
        -- Only recipes: they take the place of the professions.
        mainCondition = options.showConditions and (config.condition or "mats") or "plain"
        if recipesText ~= "" then
            sentences[1] = fill(style[mainCondition], { P = recipesText, F = fee, C = custom })
        end
        recipesText = ""
    else
        sentences[1] = fill(style[mainCondition], { P = offers.list(groups[mainCondition], language), F = fee, C = custom })
        for index = 2, #order do
            local condition = order[index]
            sentences[#sentences + 1] = fill(phrase.extra[condition], { P = offers.list(groups[condition], language), F = fee, C = custom })
        end
    end
    if recipesText ~= "" and options.highlightRecipes ~= false then
        sentences[#sentences + 1] = fill(phrase.recipesAlso, { R = recipesText })
    end
    if #sentences == 0 then return "" end
    if options.askWhisper ~= false and not (NO_WHISPER[mainCondition] and #order <= 1) then
        sentences[#sentences + 1] = style.whisper
    end
    return offers.sanitize(table.concat(sentences, " "))
end

-- Technical length: what the client sends, including the full code of every link
-- (the chat limit applies to this). Visible length: what readers see ([Name] for links).
function offers.length(text)
    return #(text or "")
end

function offers.visibleText(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x|H.-|h(.-)|h|r", "%1"):gsub("|H.-|h(.-)|h", "%1"))
end

-- Splits a message that is too long into at most `maxParts` chat lines. Cuts only between
-- sentences, otherwise between words, never inside a link. Returns the parts or nil.
function offers.split(text, limit, maxParts)
    limit, maxParts = limit or offers.MAX_LENGTH, maxParts or 2
    text = offers.sanitize(text)
    if offers.length(text) <= limit then return { text } end
    -- Words with links kept whole (a link may contain spaces inside its [name]).
    local links, words = {}, {}
    local protected = text:gsub("|c%x%x%x%x%x%x%x%x|H.-|h.-|h|r", function(link)
        links[#links + 1] = link
        return "\001" .. #links .. "\001"
    end)
    for word in protected:gmatch("%S+") do
        words[#words + 1] = (word:gsub("\001(%d+)\001", function(index) return links[tonumber(index)] end))
    end
    local function fitUntil(from, sentencesOnly)
        -- Longest run of words starting at `from` that fits; with sentencesOnly it must end a sentence.
        local best, length = nil, -1
        for index = from, #words do
            length = length + 1 + #words[index]
            if length > limit then break end
            local word = offers.visibleText(words[index])
            if not sentencesOnly or index == #words or word:match("[%.!%?。！？]$") then best = index end
        end
        return best
    end
    local parts, from = {}, 1
    while from <= #words do
        if #parts == maxParts then return nil end
        local last = fitUntil(from, true) or fitUntil(from, false)
        if not last then return nil end
        parts[#parts + 1] = table.concat(words, " ", from, last)
        from = last + 1
    end
    return parts
end

-- Comparable form of a chat line: visible text without spaces and case differences.
function offers.echoKey(text)
    return (offers.visibleText(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", ""):lower())
end

function offers.visibleLength(text)
    local count = 0
    for index = 1, #(text or "") do
        local byte = text:byte(index)
        if byte < 0x80 or byte >= 0xC0 then count = count + 1 end
    end
    return count
end

-- Shorter variants for messages over the limit. Professions are never removed and links are
-- never cut; only wording and optional parts change. Returns message and applied step keys.
local SHORTEN_STEPS = {
    { key = "shortTemplate", apply = function(config) if config.template ~= "short" and not (config.template or ""):match("^custom:") then config.template = "short" return true end end },
    { key = "noMax", apply = function(config) if config.options.showMax then config.options.showMax = false return true end end },
    { key = "recipeNames", apply = function(config) if config.options.recipeLinks then config.options.recipeLinks = false return true end end },
    { key = "professionNames", apply = function(config) if config.options.professionLinks then config.options.professionLinks = false return true end end },
    { key = "noWhisper", apply = function(config) if config.options.askWhisper ~= false then config.options.askWhisper = false return true end end },
    { key = "noSkill", apply = function(config) if config.options.showSkill then config.options.showSkill = false return true end end },
}

function offers.shorten(config, data, limit)
    limit = limit or offers.MAX_LENGTH
    local working = {}
    for key, value in pairs(config) do working[key] = value end
    working.options = {}
    for key, value in pairs(config.options or {}) do working.options[key] = value end
    local steps = {}
    local message = offers.build(working, data)
    for _, step in ipairs(SHORTEN_STEPS) do
        if offers.length(message) <= limit then break end
        if step.apply(working) then
            steps[#steps + 1] = step.key
            message = offers.build(working, data)
        end
    end
    if offers.length(message) > limit then return nil, steps end
    return message, steps
end

-- Channels -------------------------------------------------------------------------------------
-- Trade and General are recognised by their localised base names; numbers are never assumed.
local TRADE = { "trade", "handel", "commerce", "comercio", "comércio", "торговля", "거래", "交易" }
local GENERAL = { "general", "allgemein", "général", "geral", "общий", "일반", "綜合", "综合" }

local function matches(name, list)
    local lower = (name or ""):lower()
    for _, base in ipairs(list) do
        if lower == base or lower:sub(1, #base + 1) == base .. " " or lower:sub(1, #base + 2) == base .. " -" then return true end
    end
    return false
end

-- list: { { id, name, disabled } } as read from GetChannelList.
function offers.findChannel(kind, list)
    for _, channel in ipairs(list) do
        local fit = (kind == "trade" and matches(channel.name, TRADE)) or (kind == "general" and matches(channel.name, GENERAL))
            or (kind:sub(1, 5) == "name:" and channel.name == kind:sub(6))
        if fit then return channel end
    end
end

function offers.isTradeChannel(name) return matches(name, TRADE) end
function offers.isGeneralChannel(name) return matches(name, GENERAL) end

-- Local protection against accidental double posts; it does not replace server chat rules.
function offers.remaining(lastPost, cooldown, now)
    if not lastPost then return 0 end
    return math.max(0, math.ceil((lastPost + (cooldown or 120)) - now))
end

-- Orderable recipe results ----------------------------------------------------------------------
-- TRADEABLE / SERVICE are offered; NON_TRADEABLE (bind on pickup, soulbound, quest or account
-- bound) and UNKNOWN (data not loaded) are not. Both the bind type of the crafted item and the
-- binding line of a private hidden tooltip must agree.
local BOUND = { "ITEM_BIND_ON_PICKUP", "ITEM_SOULBOUND", "ITEM_BIND_QUEST", "ITEM_BIND_TO_ACCOUNT",
    "ITEM_BIND_TO_BNETACCOUNT", "ITEM_ACCOUNTBOUND", "ITEM_BNETACCOUNTBOUND", "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP" }
local FALLBACK_BOUND = { ["Wird beim Aufheben gebunden"] = true, ["Binds when picked up"] = true,
    ["Seelengebunden"] = true, ["Soulbound"] = true }
local scanner
local cache = {}

local function bindingLine(itemID, name)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "ForeverCraftOfferScanTooltip", nil, "GameTooltipTemplate")
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:ClearLines()
    local ok = pcall(scanner.SetHyperlink, scanner, "item:" .. itemID)
    local first = _G.ForeverCraftOfferScanTooltipTextLeft1
    if not ok or scanner:NumLines() == 0 or not first or first:GetText() ~= name then scanner:Hide() return nil end
    local bound = {}
    for _, key in ipairs(BOUND) do
        if type(_G[key]) == "string" then bound[_G[key]] = true end
    end
    local result = "none"
    for index = 2, math.min(scanner:NumLines(), 8) do
        local line = _G["ForeverCraftOfferScanTooltipTextLeft" .. index]
        local value = line and line:GetText()
        if value and (bound[value] or FALLBACK_BOUND[value]) then result = "bound" break end
    end
    scanner:Hide()
    return result
end

function offers.itemStatus(itemID)
    if not itemID then return "UNKNOWN" end
    if cache[itemID] then return cache[itemID] end
    local getInfo = C_Item and C_Item.GetItemInfo
    local name = getInfo and getInfo(itemID)
    if not name then
        if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        return "UNKNOWN"
    end
    local bindType = select(14, getInfo(itemID))
    local line = bindingLine(itemID, name)
    local status
    if bindType == 1 or bindType == 4 or line == "bound" then status = "NON_TRADEABLE"
    elseif line == nil then return "UNKNOWN"
    elseif bindType == 0 or bindType == 2 or bindType == 3 then status = "TRADEABLE"
    else return "UNKNOWN" end
    cache[itemID] = status
    return status
end

-- outputItemID from the recipe schematic; without a crafted item only enchanting is a service.
function offers.recipeStatus(outputItemID, professionID)
    if outputItemID and outputItemID > 0 then return offers.itemStatus(outputItemID) end
    if professionID == 333 then return "SERVICE" end
    return "UNKNOWN"
end

function offers.offerable(status) return status == "TRADEABLE" or status == "SERVICE" end
