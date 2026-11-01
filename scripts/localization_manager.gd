extends Node

## Localization Manager for Pixel Porter (PRD Section 10).
## Supports English (en), French (fr), and Arabic (ar).
## Provides RTL detection, unified translation dictionary, and dynamic language cycling.

signal language_changed(lang_code: String)

const SUPPORTED_LANGUAGES: Array[Dictionary] = [
	{ "code": "en", "name": "English", "is_rtl": false },
	{ "code": "fr", "name": "Français", "is_rtl": false },
	{ "code": "ar", "name": "العربية", "is_rtl": true }
]

var current_language: String = "en"
var save_mgr: Node = null

# Core translation dictionary (PRD Section 10: "All text lives in one translation table")
const TRANSLATIONS: Dictionary = {
	"MENU_PLAY": {
		"en": "PLAY",
		"fr": "JOUER",
		"ar": "ابدأ"
	},
	"MENU_NEW_GAME": {
		"en": "NEW GAME",
		"fr": "NOUVELLE PARTIE",
		"ar": "لعبة جديدة"
	},
	"MENU_CONTINUE": {
		"en": "CONTINUE (LEVEL %d)",
		"fr": "CONTINUER (NIVEAU %d)",
		"ar": "متابعة (المستوى %d)"
	},
	"MENU_LEVEL_SELECT": {
		"en": "LEVEL SELECT",
		"fr": "CHOIX DU NIVEAU",
		"ar": "اختيار المستوى"
	},
	"MENU_SOUND": {
		"en": "SOUND: %s",
		"fr": "SON : %s",
		"ar": "الصوت: %s"
	},
	"MENU_SOUND_ON": {
		"en": "ON",
		"fr": "OUI",
		"ar": "مفعّل"
	},
	"MENU_SOUND_OFF": {
		"en": "OFF",
		"fr": "NON",
		"ar": "معطّل"
	},
	"MENU_HAPTICS": {
		"en": "HAPTICS: %s",
		"fr": "HAPTIQUE : %s",
		"ar": "الاهتزاز: %s"
	},
	"MENU_HAPTICS_ON": {
		"en": "ON",
		"fr": "OUI",
		"ar": "مفعّل"
	},
	"MENU_HAPTICS_OFF": {
		"en": "OFF",
		"fr": "NON",
		"ar": "معطّل"
	},
	"MENU_LANGUAGE": {
		"en": "LANGUAGE: %s",
		"fr": "LANGUE : %s",
		"ar": "اللغة: %s"
	},
	"MENU_SETTINGS": {
		"en": "SETTINGS",
		"fr": "PARAMÈTRES",
		"ar": "الإعدادات"
	},
	"SETTINGS_TITLE": {
		"en": "AUDIO & SETTINGS",
		"fr": "AUDIO & PARAMÈTRES",
		"ar": "الصوت والإعدادات"
	},
	"SETTINGS_MUSIC_VOL": {
		"en": "MUSIC: %d%%",
		"fr": "MUSIQUE : %d%%",
		"ar": "الموسيقى: %d%%"
	},
	"SETTINGS_SFX_VOL": {
		"en": "SOUND FX: %d%%",
		"fr": "EFFETS : %d%%",
		"ar": "المؤثرات: %d%%"
	},
	"SETTINGS_TRACK": {
		"en": "TRACK: %s",
		"fr": "PISTE : %s",
		"ar": "المقطع: %s"
	},
	"TRACK_LOFI": {
		"en": "Warehouse Chill",
		"fr": "Entrepôt Chill",
		"ar": "هدوء المستودع"
	},
	"TRACK_INDUSTRIAL": {
		"en": "Industrial Pulse",
		"fr": "Pulsation industrielle",
		"ar": "نبض صناعي"
	},
	"SETTINGS_CONTROLS": {
		"en": "CONTROLS: %s",
		"fr": "COMMANDES : %s",
		"ar": "التحكم: %s"
	},
	"CONTROL_SWIPE": {
		"en": "SWIPE",
		"fr": "GLISSER",
		"ar": "سحب"
	},
	"CONTROL_DPAD": {
		"en": "D-PAD",
		"fr": "TOUCHES",
		"ar": "أزرار"
	},
	"CONTROL_DUAL": {
		"en": "DUAL",
		"fr": "DOUBLE",
		"ar": "مزدوج"
	},
	"SETTINGS_CLOSE": {
		"en": "Save & Close",
		"fr": "Sauvegarder & Fermer",
		"ar": "حفظ وإغلاق"
	},
	"MENU_CREDITS": {
		"en": "CREDITS",
		"fr": "CRÉDITS",
		"ar": "حول اللعبة"
	},
	"CHAPTER_0_TITLE": {
		"en": "Cargo Bay",
		"fr": "Baie de chargement",
		"ar": "خليج الشحن"
	},
	"CHAPTER_1_TITLE": {
		"en": "Cold Storage",
		"fr": "Chambre froide",
		"ar": "التخزين البارد"
	},
	"CHAPTER_2_TITLE": {
		"en": "Cyber Depot",
		"fr": "Cyber Dépôt",
		"ar": "المستودع الذكي"
	},
	"CHAPTER_TOAST": {
		"en": "CHAPTER %d: %s",
		"fr": "CHAPITRE %d : %s",
		"ar": "الفصل %d: %s"
	},
	"MENU_LOCKER": {
		"en": "SUPPLY DEPOT",
		"fr": "DÉPÔT CENTRAL",
		"ar": "مستودع الإمدادات"
	},
	"LOCKER_TITLE": {
		"en": "SUPPLY DEPOT",
		"fr": "DÉPÔT CENTRAL",
		"ar": "مستودع الإمدادات"
	},
	"LOCKER_STARS_BADGE": {
		"en": "%d / 150 Stars Collected",
		"fr": "%d / 150 Étoiles collectées",
		"ar": "%d / 150 نجمة تم جمعها"
	},
	"LOCKER_TAB_OUTFITS": {
		"en": "OUTFITS",
		"fr": "TENUES",
		"ar": "الأزياء"
	},
	"LOCKER_TAB_CRATES": {
		"en": "CRATES",
		"fr": "CAISSES",
		"ar": "الصناديق"
	},
	"LOCKER_EQUIP": {
		"en": "EQUIP",
		"fr": "ÉQUIPER",
		"ar": "تجهيز"
	},
	"LOCKER_EQUIPPED": {
		"en": "EQUIPPED",
		"fr": "ÉQUIPÉ",
		"ar": "مُجهّز"
	},
	"LOCKER_LOCKED_STARS": {
		"en": "%d Stars required",
		"fr": "%d Étoiles requises",
		"ar": "%d نجمة مطلوبة"
	},
	"SKIN_WORKER_CLASSIC": {
		"en": "Classic Denim",
		"fr": "Denim Classique",
		"ar": "جينز كلاسيكي"
	},
	"SKIN_WORKER_CLASSIC_DESC": {
		"en": "Traditional blue work overalls & red porter cap.",
		"fr": "Salopette de travail bleue traditionnelle et casquette rouge.",
		"ar": "بدلة عمل زرقاء تقليدية وقبعة حمراء."
	},
	"SKIN_WORKER_SAFETY_VEST": {
		"en": "Safety Vest",
		"fr": "Gilet de Sécurité",
		"ar": "سترة الأمان"
	},
	"SKIN_WORKER_SAFETY_VEST_DESC": {
		"en": "High-visibility neon orange with reflective safety bands.",
		"fr": "Orange fluo haute visibilité avec bandes réfléchissantes.",
		"ar": "برتقالي نيون عالي الوضوح مع أشرطة عاكسة."
	},
	"SKIN_WORKER_FOREMAN": {
		"en": "Foreman",
		"fr": "Chef d'équipe",
		"ar": "رئيس العمال"
	},
	"SKIN_WORKER_FOREMAN_DESC": {
		"en": "Hard hat and khaki uniform for senior warehouse operations.",
		"fr": "Casque de chantier et uniforme kaki d'opération.",
		"ar": "خوذة صلبة وزي كاكي لعمليات المستودع المتقدمة."
	},
	"SKIN_WORKER_GOLDEN_PORTER": {
		"en": "Golden Master",
		"fr": "Maître Doré",
		"ar": "المعلم الذهبي"
	},
	"SKIN_WORKER_GOLDEN_PORTER_DESC": {
		"en": "Legendary radiant gold uniform for master logistical porters.",
		"fr": "Uniforme d'or étincelant pour les maîtres logisticiens.",
		"ar": "زي ذهبي لامع أسطوري لخبراء الخدمات اللوجستية."
	},
	"SKIN_CRATE_CLASSIC_WOOD": {
		"en": "Classic Pine",
		"fr": "Pin Classique",
		"ar": "صنوبر كلاسيكي"
	},
	"SKIN_CRATE_CLASSIC_WOOD_DESC": {
		"en": "Standard industrial wooden cargo shipping crate.",
		"fr": "Caisse d'expédition industrielle standard en bois.",
		"ar": "صندوق شحن خشبي صناعي قياسي."
	},
	"SKIN_CRATE_STEEL_CONTAINER": {
		"en": "Steel Container",
		"fr": "Conteneur en Acier",
		"ar": "حاوية فولاذية"
	},
	"SKIN_CRATE_STEEL_CONTAINER_DESC": {
		"en": "Reinforced cold-rolled steel freight crate with metallic trim.",
		"fr": "Caisse en acier laminé à froid avec bordure métallique.",
		"ar": "صندوق شحن فولاذي مقوى بحواف معدنية."
	},
	"SKIN_CRATE_HAZARD_BOX": {
		"en": "Hazard Crate",
		"fr": "Caisse Danger",
		"ar": "صندوق الخطر"
	},
	"SKIN_CRATE_HAZARD_BOX_DESC": {
		"en": "Caution-striped high-voltage container with glowing edges.",
		"fr": "Conteneur haute tension à bandes de danger lumineuses.",
		"ar": "صندوق عالي الجهد مع خطوط تحذيرية مضيئة."
	},
	"GAME_LEVEL_LABEL": {
		"en": "LEVEL %d / %d",
		"fr": "NIVEAU %d / %d",
		"ar": "المستوى %d / %d"
	},
	"GAME_MOVES": {
		"en": "MOVES: %d",
		"fr": "DÉPLACEMENTS : %d",
		"ar": "الحركات: %d"
	},
	"GAME_PUSHES": {
		"en": "PUSHES: %d",
		"fr": "POUSSÉES : %d",
		"ar": "الدفع: %d"
	},
	"GAME_BEST": {
		"en": "BEST: %d",
		"fr": "RECORD : %d",
		"ar": "الأفضل: %d"
	},
	"BTN_RESTART": {
		"en": "Restart",
		"fr": "Recommencer",
		"ar": "إعادة"
	},
	"BTN_UNDO": {
		"en": "Undo",
		"fr": "Annuler",
		"ar": "تراجع"
	},
	"BTN_PREV": {
		"en": "Prev",
		"fr": "Préc",
		"ar": "السابق"
	},
	"BTN_NEXT": {
		"en": "Next",
		"fr": "Suiv",
		"ar": "التالي"
	},
	"BTN_BACK": {
		"en": "Back",
		"fr": "Retour",
		"ar": "رجوع"
	},
	"BTN_HINT": {
		"en": "Hint",
		"fr": "Indice",
		"ar": "تلميح"
	},
	"HINT_DEADLOCK": {
		"en": "No solution from here! Tap Undo",
		"fr": "Bloqué ! Appuyez sur Annuler",
		"ar": "طريق مسدود! اضغط تراجع"
	},
	"HINT_NO_PATH": {
		"en": "No clear path found. Try another move or Undo",
		"fr": "Aucun chemin trouvé. Essayez un autre coup ou Annuler",
		"ar": "لم يتم العثور على مسار. جرب حركة أخرى أو تراجع"
	},
	"HINT_ALREADY_SOLVED": {
		"en": "Level already completed!",
		"fr": "Niveau déjà terminé !",
		"ar": "المستوى مكتمل بالفعل!"
	},
	"HINT_STEP_UP": {
		"en": "Hint: Move UP",
		"fr": "Indice : Vers le HAUT",
		"ar": "تلميح: تحرك لأعلى"
	},
	"HINT_STEP_DOWN": {
		"en": "Hint: Move DOWN",
		"fr": "Indice : Vers le BAS",
		"ar": "تلميح: تحرك لأسفل"
	},
	"HINT_STEP_LEFT": {
		"en": "Hint: Move LEFT",
		"fr": "Indice : Vers la GAUCHE",
		"ar": "تلميح: تحرك لليسار"
	},
	"HINT_STEP_RIGHT": {
		"en": "Hint: Move RIGHT",
		"fr": "Indice : Vers la DROITE",
		"ar": "تلميح: تحرك لليمين"
	},
	"SPLASH_INIT": {
		"en": "INITIALIZING SYSTEM...",
		"fr": "INITIALISATION DU SYSTÈME...",
		"ar": "جاري تهيئة النظام..."
	},
	"SPLASH_LEVELS": {
		"en": "LOADING 50 SOKOBAN LEVELS...",
		"fr": "CHARGEMENT DE 50 NIVEAUX SOKOBAN...",
		"ar": "تحميل 50 مرحلة سوكوبان..."
	},
	"SPLASH_READY": {
		"en": "READY! TAP TO START",
		"fr": "PRÊT ! TOUCHER POUR DÉMARRER",
		"ar": "جاهز! المس للبدء"
	},
	"LEVEL_SELECT_TITLE": {
		"en": "SELECT LEVEL",
		"fr": "CHOIX DU NIVEAU",
		"ar": "اختيار المستوى"
	},
	"WIN_BANNER": {
		"en": "LEVEL COMPLETED!",
		"fr": "NIVEAU TERMINÉ !",
		"ar": "اكتمل المستوى!"
	},
	"STAT_MOVES_TITLE": {
		"en": "MOVES",
		"fr": "MOUV.",
		"ar": "حركات"
	},
	"STAT_TIME_TITLE": {
		"en": "TIME",
		"fr": "TEMPS",
		"ar": "الوقت"
	},
	"STAT_PUSHES_TITLE": {
		"en": "PUSHES",
		"fr": "POUSSÉES",
		"ar": "دفعات"
	},
	"WIN_RETRY_BTN": {
		"en": "Retry",
		"fr": "Rejouer",
		"ar": "إعادة"
	},
	"WIN_TARGET_HINT": {
		"en": "Target: ≤ %d moves",
		"fr": "Objectif : ≤ %d mouv.",
		"ar": "الهدف: ≤ %d حركة"
	},
	"WIN_TITLE": {
		"en": "LEVEL %d COMPLETED!",
		"fr": "NIVEAU %d TERMINÉ !",
		"ar": "اكتمل المستوى %d!"
	},
	"WIN_STATS": {
		"en": "Solved in %d moves (%d pushes)\nBest: %d moves (%d pushes)",
		"fr": "Résolu en %d mouvements (%d poussées)\nRecord : %d mouvements (%d poussées)",
		"ar": "تم الحل في %d حركة (%d دفعة)\nأفضل نتيجة: %d حركة (%d دفعة)"
	},
	"WIN_NEXT_BTN": {
		"en": "Next Level",
		"fr": "Niveau Suivant",
		"ar": "المستوى التالي"
	},
	"WIN_MENU_BTN": {
		"en": "Menu",
		"fr": "Menu",
		"ar": "القائمة"
	},
	"RESTART_CONFIRM": {
		"en": "You've made %d moves. Restart this level?",
		"fr": "Vous avez fait %d mouvements. Recommencer ce niveau ?",
		"ar": "لقد قمت بـ %d حركة. هل ترغب في إعادة هذا المستوى؟"
	},
	"CREDITS_TITLE": {
		"en": "PIXEL SOKOBAN CREDITS",
		"fr": "CRÉDITS PIXEL SOKOBAN",
		"ar": "معلومات PIXEL SOKOBAN"
	},
	"CREDITS_BODY": {
		"en": "A retro box-pushing puzzle game.\nBuilt with Godot Engine 4.\n\nDesign & Logic: Pixel Sokoban Team\nSolver & generator verified solvable.\nOpen commercial game assets.\n\nThank you for playing!",
		"fr": "Jeu de réflexion rétro de poussée de caisses.\nDéveloppé avec Godot Engine 4.\n\nDesign & Logique : Équipe Pixel Sokoban\nNiveaux vérifiés par solveur automatique.\nActifs sous licences libres commerciales.\n\nMerci d'avoir joué !",
		"ar": "لعبة ألغاز ريترو كلاسيكية لدفع الصناديق.\nتم التطوير بواسطة محرك Godot 4.\n\nالتصميم والبرمجة: فريق Pixel Sokoban\nجميع المستويات تم حلها والتحقق منها برمجياً.\nالموارد مرخصة برخص تجارية مفتوحة.\n\nشكراً لك على اللعب!"
	},
	"BTN_CLOSE": {
		"en": "Close",
		"fr": "Fermer",
		"ar": "إغلاق"
	},
	"BTN_CAMPAIGN_COMPLETE": {
		"en": "Finish Campaign",
		"fr": "Terminer la campagne",
		"ar": "إنهاء الحملة"
	},
	"END_TITLE": {
		"en": "CAMPAIGN COMPLETED!",
		"fr": "CAMPAGNE TERMINÉE !",
		"ar": "اكتملت الحملة بنجاح!"
	},
	"END_THANKS": {
		"en": "Thank you for playing Pixel Sokoban: Warehouse Rush!\nYou have mastered all 50 warehouse puzzles.",
		"fr": "Merci d'avoir joué à Pixel Sokoban: Warehouse Rush !\nVous avez maîtrisé les 50 défis d'entrepôt.",
		"ar": "شكراً لك على لعب Pixel Sokoban: Warehouse Rush!\nلقد تمكنت من حل جميع ألغاز المستودع الـ 50."
	},
	"END_MORE_LEVELS": {
		"en": "More levels coming soon!",
		"fr": "Plus de niveaux bientôt disponibles !",
		"ar": "المزيد من المستويات قريباً!"
	},
	"END_STATS_SUMMARY": {
		"en": "Levels Solved: %d / 50\nTotal Best Moves: %d\nTotal Best Pushes: %d",
		"fr": "Niveaux résolus : %d / 50\nTotal meilleurs mouvements : %d\nTotal meilleures poussées : %d",
		"ar": "المستويات المحلولة: %d / 50\nإجمالي أفضل الحركات: %d\nإجمالي أفضل الدفعات: %d"
	},
	"BTN_MAIN_MENU": {
		"en": "Main Menu",
		"fr": "Menu Principal",
		"ar": "القائمة الرئيسية"
	},
	"BTN_REPLAY_LEVELS": {
		"en": "Level Select",
		"fr": "Choix du Niveau",
		"ar": "اختيار المستوى"
	},
	"MODAL_REWARD_TITLE": {
		"en": "NEED A HINT?",
		"fr": "BESOIN D'UN INDICE ?",
		"ar": "تحتاج مساعدة؟"
	},
	"MODAL_REWARD_DESC": {
		"en": "You're out of hints. Watch a sponsor video to receive +3 Free Hints!",
		"fr": "Vous n'avez plus d'indices. Regardez une courte vidéo pour recevoir 3 indices gratuits !",
		"ar": "نفدت تلميحاتك. شاهد فيديو للحصول على 3 تلميحات مجانية!"
	},
	"BTN_WATCH_AD": {
		"en": "WATCH AD (+3 HINTS)",
		"fr": "REGARDER (+3 INDICES)",
		"ar": "مشاهدة إعلان (+3 تلميحات)"
	},
	"TOAST_HINTS_ADDED": {
		"en": "+3 Hints Added!",
		"fr": "+3 Indices Ajoutés !",
		"ar": "تمت إضافة 3 تلميحات!"
	},
	"MENU_ACHIEVEMENTS": {
		"en": "ACHIEVEMENTS",
		"fr": "SUCCÈS",
		"ar": "الإنجازات"
	},
	"ACHIEVEMENTS_TITLE": {
		"en": "WAREHOUSE ACHIEVEMENTS",
		"fr": "SUCCÈS DU PORTEUR",
		"ar": "إنجازات المستودع"
	},
	"ACHIEVEMENTS_COUNTER": {
		"en": "%d / 9 Unlocked",
		"fr": "%d / 9 Débloqués",
		"ar": "%d / 9 تم الفتح"
	},
	"ACH_FIRST_SHIFT": {
		"en": "First Shift",
		"fr": "Première Équipe",
		"ar": "الوردية الأولى"
	},
	"ACH_FIRST_SHIFT_DESC": {
		"en": "Complete your very first warehouse shift.",
		"fr": "Terminez votre toute première livraison.",
		"ar": "أكمل ورديتك الأولى في المستودع."
	},
	"ACH_CARGO_MASTER": {
		"en": "Logistics Specialist",
		"fr": "Spécialiste Logistique",
		"ar": "خبير لوجستي"
	},
	"ACH_CARGO_MASTER_DESC": {
		"en": "Conquer all 15 levels of Chapter 1 Cargo Bay.",
		"fr": "Terminez les 15 niveaux de la Baie de chargement.",
		"ar": "أتقن جميع مستويات خليج الشحن الـ 15."
	},
	"ACH_COLD_STORAGE": {
		"en": "Sub-Zero Handler",
		"fr": "Manutentionnaire Polaire",
		"ar": "معالج الصقيع"
	},
	"ACH_COLD_STORAGE_DESC": {
		"en": "Conquer all 20 levels of Chapter 2 Cold Storage.",
		"fr": "Terminez les 20 niveaux de la Chambre froide.",
		"ar": "أتقن جميع مستويات التخزين البارد الـ 20."
	},
	"ACH_DEPOT_CLEARED": {
		"en": "Unstoppable Porter",
		"fr": "Porteur Inarrêtable",
		"ar": "حمال لا يتوقف"
	},
	"ACH_DEPOT_CLEARED_DESC": {
		"en": "Complete all 50 handcrafted warehouse levels.",
		"fr": "Terminez les 50 niveaux du jeu.",
		"ar": "أكمل جميع مستويات المستودع الـ 50."
	},
	"ACH_PRECISION_STARTER": {
		"en": "Precision Starter",
		"fr": "Apprenti Précis",
		"ar": "مبتدئ دقيق"
	},
	"ACH_PRECISION_STARTER_DESC": {
		"en": "Earn 3 stars on at least 5 levels.",
		"fr": "Obtenez 3 étoiles sur au moins 5 niveaux.",
		"ar": "احصل على 3 نجوم في 5 مستويات على الأقل."
	},
	"ACH_PRECISION_MASTER": {
		"en": "Precision Master",
		"fr": "Maître de la Précision",
		"ar": "أستاذ الدقة"
	},
	"ACH_PRECISION_MASTER_DESC": {
		"en": "Earn 3 stars on at least 25 levels.",
		"fr": "Obtenez 3 étoiles sur au moins 25 niveaux.",
		"ar": "احصل على 3 نجوم في 25 مستوى على الأقل."
	},
	"ACH_PERFECTIONIST": {
		"en": "Puzzle Perfectionist",
		"fr": "Perfectionniste Absolu",
		"ar": "خبير الألغاز المتقن"
	},
	"ACH_PERFECTIONIST_DESC": {
		"en": "Achieve 3 stars on all 50 levels (150 Stars).",
		"fr": "Obtenez 3 étoiles sur les 50 niveaux (150 étoiles).",
		"ar": "احصل على 3 نجوم في جميع المستويات الـ 50 (150 نجمة)."
	},
	"ACH_STYLIN_PORTER": {
		"en": "Stylin' Porter",
		"fr": "Porteur Stylé",
		"ar": "حمال أنيق"
	},
	"ACH_STYLIN_PORTER_DESC": {
		"en": "Equip any unlockable cosmetic from the Supply Depot.",
		"fr": "Équipez une tenue ou caisse du Dépôt Central.",
		"ar": "جهّز أي عنصر من مستودع الإمدادات."
	},
	"ACH_HEAVY_LIFTER": {
		"en": "Heavy Lifter",
		"fr": "Force Herculéenne",
		"ar": "رافع الأثقال"
	},
	"ACH_HEAVY_LIFTER_DESC": {
		"en": "Push 100 crates across all your warehouse shifts.",
		"fr": "Poussez 100 caisses au total.",
		"ar": "ادفع 100 صندوق عبر جولاتك في المستودع."
	}
}


func _ready() -> void:
	if is_inside_tree() and get_tree().root.has_node("SaveManager"):
		save_mgr = get_tree().root.get_node("SaveManager")
		if "language" in save_mgr and not save_mgr.language.is_empty():
			current_language = save_mgr.language

	_register_godot_translations()
	set_language(current_language)


func _register_godot_translations() -> void:
	for lang in ["en", "fr", "ar"]:
		var tr_obj: Translation = Translation.new()
		tr_obj.locale = lang
		for key in TRANSLATIONS.keys():
			var msg: String = TRANSLATIONS[key].get(lang, TRANSLATIONS[key].get("en", ""))
			tr_obj.add_message(key, msg)
		TranslationServer.add_translation(tr_obj)


## Sets current language and updates TranslationServer & SaveManager.
func set_language(lang_code: String) -> void:
	if not has_language(lang_code):
		lang_code = "en"

	current_language = lang_code
	TranslationServer.set_locale(current_language)

	if save_mgr != null and "language" in save_mgr:
		save_mgr.language = current_language
		save_mgr.save_data()

	language_changed.emit(current_language)


## Returns whether the given language code is supported.
func has_language(lang_code: String) -> bool:
	for item in SUPPORTED_LANGUAGES:
		if item["code"] == lang_code:
			return true
	return false


## Returns true if current language is Right-to-Left (e.g. Arabic).
func is_rtl() -> bool:
	for item in SUPPORTED_LANGUAGES:
		if item["code"] == current_language:
			return item.get("is_rtl", false)
	return false


## Cycles to the next supported language and returns its code.
func cycle_language() -> String:
	var next_idx: int = 0
	for i in range(SUPPORTED_LANGUAGES.size()):
		if SUPPORTED_LANGUAGES[i]["code"] == current_language:
			next_idx = (i + 1) % SUPPORTED_LANGUAGES.size()
			break
	var next_code: String = SUPPORTED_LANGUAGES[next_idx]["code"]
	set_language(next_code)
	return next_code


## Returns the display name of the current or specified language.
func get_language_display_name(lang_code: String = "") -> String:
	var target: String = lang_code if not lang_code.is_empty() else current_language
	for item in SUPPORTED_LANGUAGES:
		if item["code"] == target:
			return item["name"]
	return "English"


## Returns translated string for key with optional sprintf arguments.
func tr_text(key: String, args: Array = []) -> String:
	var entry: Dictionary = TRANSLATIONS.get(key, {})
	var text: String = entry.get(current_language, entry.get("en", key))
	if not args.is_empty():
		return text % args
	return text
