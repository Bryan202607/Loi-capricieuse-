extends RefCounted
# Catalogue des lois de la nature. Chaque jour, deux lois de groupes
# différents sont tirées au sort. Pour ajouter une loi : une entrée ici
# (avec son conseil "tip" affiché après 5 défaites) + son effet dans
# apply_laws() de main.gd.

static func all() -> Array:
	return [
		{
			"id": "eau_monte",
			"group": "river",
			"name": "L'eau remonte",
			"desc": "Le bateau est poussé vers le nord.",
			"tip": "Le bateau monte vite mais redescend lentement : prends 3 fruits par voyage.",
			"color": Color("4aa8ee"),
		},
		{
			"id": "eau_solide",
			"group": "river",
			"name": "L'eau est solide",
			"desc": "Rivière gelée : traverse-la à pied.",
			"tip": "Marche directement sur la glace, sans bateau.",
			"color": Color("b8e6fa"),
		},
		{
			"id": "bateau_fou",
			"group": "river",
			"name": "Bateau fou",
			"desc": "Le bateau file à toute allure.",
			"tip": "Le bateau ne s'arrête que très peu : attends-le près du quai, prêt à embarquer.",
			"color": Color("ff7043"),
		},
		{
			"id": "fruits_timides",
			"group": "fruit",
			"name": "Fruits timides",
			"desc": "Les fruits fuient quand tu approches.",
			"tip": "Coince les fruits contre le bord de l'écran ou de la rivière.",
			"color": Color("f39c3d"),
		},
		{
			"id": "fruits_aimants",
			"group": "fruit",
			"name": "Fruits aimants",
			"desc": "Les fruits viennent vers toi.",
			"tip": "Attends près de la rive nord : les fruits viennent à toi.",
			"color": Color("f06aa8"),
		},
		{
			"id": "fruits_vagabonds",
			"group": "fruit",
			"name": "Fruits vagabonds",
			"desc": "Les fruits se promènent partout.",
			"tip": "Ne cours pas après eux : place-toi et attrape-les quand ils passent près de toi.",
			"color": Color("c0ca33"),
		},
		{
			"id": "pieds_plume",
			"group": "body",
			"name": "Pieds de plume",
			"desc": "Tu vas vite, mais tu glisses.",
			"tip": "Tu glisses un peu : touche un point loin de l'eau, jamais le bord.",
			"color": Color("f5d442"),
		},
		{
			"id": "pieds_plomb",
			"group": "body",
			"name": "Pieds de plomb",
			"desc": "Tu es lent, mais le bateau attend plus longtemps.",
			"tip": "Le bateau patiente au quai : prends 3 fruits à chaque voyage.",
			"color": Color("9aa7a8"),
		},
		{
			"id": "grand_sac",
			"group": "body",
			"name": "Grand sac",
			"desc": "Ton sac contient 5 fruits, mais tu es plus lent.",
			"tip": "Remplis ton sac (5 fruits) avant de traverser : un seul voyage suffit.",
			"color": Color("a1887f"),
		},
		{
			"id": "miroir",
			"group": "body",
			"name": "Monde miroir",
			"desc": "Gauche et droite sont inversées.",
			"tip": "Touche du côté opposé : pour aller à droite, touche à gauche.",
			"color": Color("b07ad8"),
		},
		{
			"id": "vent_est",
			"group": "wind",
			"name": "Vent d'est",
			"desc": "Un vent pousse tout vers l'est.",
			"tip": "Le vent te décale à droite : vise un peu plus à gauche.",
			"color": Color("33c9a8"),
		},
		{
			"id": "nuit",
			"group": "sky",
			"name": "Nuit magique",
			"desc": "La nuit tombe : les fruits brillent.",
			"tip": "Cherche la lueur dorée des fruits dans l'obscurité.",
			"color": Color("7986cb"),
		},
		{
			"id": "pluie",
			"group": "sky",
			"name": "Pluie glissante",
			"desc": "Il pleut : le sol devient glissant.",
			"tip": "Le sol glisse : touche un point loin de l'eau et laisse-toi freiner.",
			"color": Color("78a4c8"),
		},
	]
