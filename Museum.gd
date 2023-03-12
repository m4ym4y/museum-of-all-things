extends Spatial

const Exhibit = preload("res://Exhibit.tscn")
const starting_exhibit = "Albert_Einstein"
const static_exhibit_data = {
	"Albert_Einstein": {
		"items": [
			{
				"type": "image",
				"src": "//upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Einstein_1921_by_F_Schmutzer_-_restoration.jpg/640px-Einstein_1921_by_F_Schmutzer_-_restoration.jpg",
				"text": "caption"
			},
			{
				"type": "text",
				"text": "Albert Einstein (/ˈaɪnstaɪn/ EYEN-styne;[6] German: [ˈalbɛʁt ˈʔaɪnʃtaɪn] (listen); 14 March 1879 – 18 April 1955) was a German-born theoretical physicist,[7] widely acknowledged to be one of the greatest and most influential physicists of all time. Einstein is best known for developing the theory of relativity, but he also made important contributions to the development of the theory of quantum mechanics. Relativity and quantum mechanics are the two pillars of modern physics.[3][8] His mass–energy equivalence formula E = mc2, which arises from relativity theory, has been dubbed 'the world's most famous equation'."
			},
			{
				"type": "image",
				"src": "//upload.wikimedia.org/wikipedia/commons/thumb/f/fb/Albert_Einstein_at_the_age_of_three_%281882%29.jpg/320px-Albert_Einstein_at_the_age_of_three_%281882%29.jpg",
				"text": "Einstein at the age of three in 1882"
			},
			{
				"type": "text",
				"text": "His work is also known for its influence on the philosophy of science.[10][11] He received the 1921 Nobel Prize in Physics 'for his services to theoretical physics, and especially for his discovery of the law of the photoelectric effect',[12] a pivotal step in the development of quantum theory. His intellectual achievements and originality resulted in 'Einstein' becoming synonymous with 'genius'.[13] Einsteinium, one of the synthetic elements in the periodic table, was named in his honor."
			},
			{
				"type": "image",
				"src": "//upload.wikimedia.org/wikipedia/commons/thumb/a/ad/Albert_Einstein_as_a_child.jpg/640px-Albert_Einstein_as_a_child.jpg",
				"text": "Einstein in 1893 (age 14)"
			},
			{
				"type": "image",
				"src": "//upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Albert_Einstein%27s_exam_of_maturity_grades_%28color2%29.jpg/640px-Albert_Einstein%27s_exam_of_maturity_grades_%28color2%29.jpg",
				"text": "Einstein's Matura certificate, 1896[note 2]"
			},
			{
				"type": "image",
				"src": "//upload.wikimedia.org/wikipedia/commons/thumb/8/87/Albert_Einstein_and_his_wife_Mileva_Maric.jpg/640px-Albert_Einstein_and_his_wife_Mileva_Maric.jpg",
				"text": "Albert Einstein and Mileva Marić Einstein, 1912"
			},
			{
				"type": "image",
				"src": "//upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Einstein_patentoffice.jpg/640px-Einstein_patentoffice.jpg",
				"text": "Einstein in 1904 (age 25)"
			},
			{
				"type": "image",
				"src": "//upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Einstein_thesis.png/640px-Einstein_thesis.png",
				"text": "Cover image of the PhD dissertation of Albert Einstein defended in 1905"
			},
		],
		"doors": [
			"Theory_of_Relativity",
			"Astronomy"
		]
	},
	"Astronomy": {
		"items": [
			{
				"type": "image",
				"src": "https://en.wikipedia.org/wiki/File:Laser_Towards_Milky_Ways_Centre.jpg",
				"text": "The Paranal Observatory of European Southern Observatory shooting a laser guide star to the Galactic Center"
			},
			{
				"type": "text",
				"text": "Astronomy (from Ancient Greek ἀστρονομία (astronomía) 'science that studies the laws of the stars') is a natural science that studies celestial objects and phenomena. It uses mathematics, physics, and chemistry in order to explain their origin and evolution. Objects of interest include planets, moons, stars, nebulae, galaxies, and comets. Relevant phenomena include supernova explosions, gamma ray bursts, quasars, blazars, pulsars, and cosmic microwave background radiation. More generally, astronomy studies everything that originates beyond Earth's atmosphere. Cosmology is a branch of astronomy that studies the universe as a whole.[1]"
			}
		],
		"doors": []
	},
	"Theory_of_Relativity": {
		"items": [
			{
				"type": "image",
				"src": "https://upload.wikimedia.org/wikipedia/commons/thumb/0/06/Michelson-Morley_experiment_%28en%29.svg/220px-Michelson-Morley_experiment_%28en%29.svg.png",
				"text": "A diagram of the Michelson–Morley experiment"
			},
			{
				"type": "text",
				"text": "The theory of relativity usually encompasses two interrelated physics theories by Albert Einstein; special relativity and general relativity, proposed and published in 1905 and 1915, respectively.[1] Special relativity applies to all physical phenomena in the absence of gravity. General relativity explains the law of gravitation and its relation to the forces of nature.[2] It applies to the cosmological and astrophysical realm, including astronomy.[3]"
			}
		],
		"doors": []
	}
}

var loaded_exhibits = {}

func load_exhibit(title):
	var exhibit = Exhibit.instance()

	# TODO: load dynamically from wikipedia
	exhibit.init(static_exhibit_data[title])
	loaded_exhibits[title] = exhibit

	# TODO: position exhibit at the correct location according to the triggered door
	add_child(exhibit)

func _ready():
	load_exhibit(starting_exhibit)
