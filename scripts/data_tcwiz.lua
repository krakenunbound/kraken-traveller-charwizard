-- Traveller (Mongoose 2E) character creation data. Package TCData.
-- Transcribed from the MGT2 Core Rulebook module (chapter 1, Traveller Creation,
-- and chapter 10, Psion). The ruleset's career records carry only the
-- qualification and assignment text, so the tables live here.
--
-- Effects (fx) are lists of ops run by TCWizard.runFx; see dev/DESIGN.md.
-- A skill spec string is parsed by TCWizard.parseSpec:
--   "Gun Combat" = +1 level; "Recon 1" = at least level 1; "Admin 0" = level 0;
--   "DEX +1" = characteristic; "Drive or Flyer" = choose one;
--   "Contact" / "Ally" / "Rival" / "Enemy" = an associate.

-- Stats: str dex end int edu soc psi.
STATS = { "str", "dex", "end", "int", "edu", "soc" };
STAT_NAMES = { str = "Strength", dex = "Dexterity", ["end"] = "Endurance", int = "Intellect", edu = "Education", soc = "Social Standing", psi = "Psionic Strength" };
STAT_SHORT = { str = "STR", dex = "DEX", ["end"] = "END", int = "INT", edu = "EDU", soc = "SOC", psi = "PSI" };
PHYSICAL = { "str", "dex", "end" };
MENTAL = { "int", "edu", "soc" };

local function G(sName, nLevel) return { "gain", sName, nLevel }; end
local function PICK(...) return { "pick", { ... } }; end
local function OPT(sLabel, tFx) return { label = sLabel, fx = tFx }; end
local function CH(...) return { "choice", { ... } }; end
local function CHK(tRolls, nTarget, tOk, tFail, tTwo) return { "check", rolls = tRolls, target = nTarget, ok = tOk, fail = tFail, two = tTwo }; end
local function NOTE(s) return { "note", s }; end

-- "Severely injured (this is the same as a result of 2 on the Injury Table).
-- Alternatively, roll twice on the Injury Table and take the lower result."
local SEVERE = CH(OPT("Severely injured (Injury Table result 2)", { { "injury", 2 } }),
	OPT("Roll twice on the Injury Table, take the lower", { { "injury", "lower" } }));
local SEVERE_TEXT = "Severely injured (this is the same as a result of 2 on the Injury Table). Alternatively, roll twice on the Injury Table and take the lower result.";
local DISASTER = { text = "Disaster! Roll on the Mishap Table, but you are not ejected from this career.", fx = { { "mishap", noeject = true } } };
local LIFE = { text = "Life Event. Roll on the Life Events Table.", fx = { { "life" } } };
local BETRAYED = { "convert", fallback = true };

-- Background skills (EDU DM + 3 of these at level 0).
BACKGROUND_SKILLS = { "Admin", "Animals", "Art", "Athletics", "Carouse", "Drive", "Electronics", "Flyer", "Language",
	"Mechanic", "Medic", "Profession", "Science", "Seafarer", "Streetwise", "Survival", "Vacc Suit" };

-- Every skill in the book (for "any skill"); specialties come from the loaded skill records.
ALL_SKILLS = { "Admin", "Advocate", "Animals", "Art", "Astrogation", "Athletics", "Broker", "Carouse", "Deception",
	"Diplomat", "Drive", "Electronics", "Engineer", "Explosives", "Flyer", "Gambler", "Gun Combat", "Gunner",
	"Heavy Weapons", "Investigate", "Jack-of-all-Trades", "Language", "Leadership", "Mechanic", "Medic", "Melee",
	"Navigation", "Persuade", "Pilot", "Profession", "Recon", "Science", "Seafarer", "Stealth", "Steward",
	"Streetwise", "Survival", "Tactics", "Vacc Suit" };

-- Specialties used when no skill record names them (the loaded books add more).
SPECIALTIES = {
	["Animals"] = { "handling", "training", "veterinary" },
	["Art"] = { "performer", "holography", "instrument", "visual media", "write" },
	["Athletics"] = { "dexterity", "endurance", "strength" },
	["Drive"] = { "hovercraft", "mole", "track", "walker", "wheel" },
	["Electronics"] = { "comms", "computers", "remote ops", "sensors" },
	["Engineer"] = { "m-drive", "j-drive", "life support", "power" },
	["Flyer"] = { "airship", "grav", "ornithopter", "rotor", "wing" },
	["Gun Combat"] = { "archaic", "energy", "slug" },
	["Gunner"] = { "turret", "ortillery", "screen", "capital" },
	["Heavy Weapons"] = { "artillery", "man portable", "vehicle" },
	["Language"] = { "anglic", "vilani", "zdetl", "oynprith" },
	["Melee"] = { "unarmed", "blade", "bludgeon", "natural" },
	["Pilot"] = { "small craft", "spacecraft", "capital ships" },
	["Profession"] = { "belter", "biologicals", "civil engineering", "construction", "hydroponics", "polymers" },
	["Science"] = { "archaeology", "astronomy", "biology", "chemistry", "cosmology", "cybernetics", "economics",
		"genetics", "history", "linguistics", "philosophy", "physics", "planetology", "psionicology", "psychology",
		"robotics", "sophontology", "xenology" },
	["Seafarer"] = { "ocean ships", "personal", "sail", "submarine" },
	["Tactics"] = { "military", "naval" },
};

PSI_TALENTS = { "Telepathy", "Clairvoyance", "Telekinesis", "Awareness", "Teleportation" };
PSI_LEARN_DM = { Telepathy = 4, Clairvoyance = 3, Telekinesis = 2, Awareness = 1, Teleportation = 0 };

-- Characteristic Modifiers table.
function getDM(n)
	n = tonumber(n) or 0;
	if n <= 0 then return -3; end
	if n <= 2 then return -2; end
	if n <= 5 then return -1; end
	if n <= 8 then return 0; end
	if n <= 11 then return 1; end
	if n <= 14 then return 2; end
	return 3;
end

NOBLE_TITLES = { [11] = "Knight", [12] = "Baron", [13] = "Marquis", [14] = "Count", [15] = "Duke" };

-- Injury Table (1D).
INJURY = {
	[1] = { text = "Nearly killed - reduce one physical characteristic by 1D, reduce two other physical characteristics by 2.", fx = { { "nearlykilled" } } },
	[2] = { text = "Severely injured - reduce one physical characteristic by 1D.", fx = { { "statpick", PHYSICAL, "-1D" } } },
	[3] = { text = "Missing Eye or Limb - reduce STR or DEX by 2.", fx = { { "statpick", { "str", "dex" }, -2 } } },
	[4] = { text = "Scarred - you are scarred and injured. Reduce any physical characteristic by 2.", fx = { { "statpick", PHYSICAL, -2 } } },
	[5] = { text = "Injured. Reduce any physical characteristic by 1.", fx = { { "statpick", PHYSICAL, -1 } } },
	[6] = { text = "Lightly Injured. No permanent effect.", fx = {} },
};

-- Ageing Table (2D - total terms, + terms on anagathics). Lowest row is -6.
AGEING = {
	[-6] = { text = "Reduce three physical characteristics by 2, reduce one mental characteristic by 1.", phys = { 2, 2, 2 }, ment = 1 },
	[-5] = { text = "Reduce three physical characteristics by 2.", phys = { 2, 2, 2 } },
	[-4] = { text = "Reduce two physical characteristics by 2, reduce one physical characteristic by 1.", phys = { 2, 2, 1 } },
	[-3] = { text = "Reduce one physical characteristic by 2, reduce two physical characteristics by 1.", phys = { 2, 1, 1 } },
	[-2] = { text = "Reduce three physical characteristics by 1.", phys = { 1, 1, 1 } },
	[-1] = { text = "Reduce two physical characteristics by 1.", phys = { 1, 1 } },
	[0] = { text = "Reduce one physical characteristic by 1.", phys = { 1 } },
	[1] = { text = "No effect.", phys = {} },
};

-- Draft Table (1D).
DRAFT = {
	[1] = { career = "navy" }, [2] = { career = "army" }, [3] = { career = "marine" },
	[4] = { career = "merchant", assignment = "marine" }, [5] = { career = "scout" },
	[6] = { career = "agent", assignment = "law" },
};

-- Benefits of Rank: extra Benefit rolls by highest rank reached.
function getRankBenefitRolls(nRank)
	if nRank >= 5 then return 3; end
	if nRank >= 3 then return 2; end
	if nRank >= 1 then return 1; end
	return 0;
end

-- Pensions: 5+ terms in a career other than Scout, Rogue, Prisoner, Drifter.
function getPension(nTerms)
	if nTerms < 5 then return 0; end
	if nTerms <= 8 then return ({ [5] = 10000, [6] = 12000, [7] = 14000, [8] = 16000 })[nTerms]; end
	return 16000 + (nTerms - 8) * 2000;
end

-- Medical Bills: share of the cost the employer pays, 2D + rank.
MEDICAL = {
	military = { { 4, 75 }, { 8, 100 }, { 12, 100 } },
	civil = { { 4, 50 }, { 8, 75 }, { 12, 100 } },
	rough = { { 4, 0 }, { 8, 50 }, { 12, 75 } },
};
MEDICAL_COST_PER_POINT = 5000;

-- Life Event Table (2D).
LIFE_EVENTS = {
	[2] = { text = "Sickness or Injury: You are injured or become sick. Roll on the Injury Table.", fx = { { "injury" } } },
	[3] = { text = "Birth or Death: Someone close to you dies, like a friend or family member. Alternatively, someone close to you gives birth (or is born!). You are involved in some fashion (father or mother, relative, godparent, etc).", fx = {} },
	[4] = { text = "Ending of Relationship: A romantic relationship involving you ends. Badly. Gain a Rival or Enemy.", fx = { PICK("Rival", "Enemy") } },
	[5] = { text = "Improved Relationship: A romantic relationship involving you deepens, possibly leading to marriage or some other emotional commitment. Gain an Ally.", fx = { { "assoc", "ally", 1 } } },
	[6] = { text = "New Relationship: You become involved in a romantic relationship. Gain an Ally.", fx = { { "assoc", "ally", 1 } } },
	[7] = { text = "New Contact: You gain a new Contact.", fx = { { "assoc", "contact", 1 } } },
	[8] = { text = "Betrayal: You are betrayed in some fashion by a friend. If you have any Contacts or Allies, convert one into a Rival or Enemy. Otherwise, gain a Rival or an Enemy.", fx = { BETRAYED } },
	[9] = { text = "Travel: You move to another world. You gain DM+2 to your next Qualification roll.", fx = { { "qdm", 2 } } },
	[10] = { text = "Good Fortune: Something good happens to you, you come into money unexpectedly, have a lifelong dream come true, get a book published or have some other stroke of good fortune. Gain DM+2 to any one Benefit roll.", fx = { { "bdm", 2 } } },
	[11] = { text = "Crime: You commit or are the victim (or are accused) of a crime. Lose one Benefit roll or take the Prisoner career in your next term.", fx = { CH(OPT("Lose one Benefit roll", { { "blose", 1 } }), OPT("Take the Prisoner career next term", { { "prisoner" } })) } },
	[12] = { text = "Unusual Event: Something weird happens.", fx = { { "unusual" } } },
};

-- Unusual Event (1D).
UNUSUAL = {
	[1] = { text = "Psionics: You encounter a Psionic institute. You may immediately test your Psionic Strength and, if you qualify, take the Psion career in your next term.", fx = { { "psitest" } } },
	[2] = { text = "Aliens: You spend time among an alien race. Gain Science 1 and a Contact among an alien race.", fx = { G("Science", 1), { "assoc", "contact", 1, note = "among an alien race" } } },
	[3] = { text = "Alien Artefact: You have a strange and unusual device from an alien culture that is not normally available to humans.", fx = { NOTE("Alien artefact (the referee decides what it is)") } },
	[4] = { text = "Amnesia: Something happened to you, but you do not know what it was.", fx = {} },
	[5] = { text = "Contact with Government: You briefly came into contact with the highest echelons of the Imperium - an Archduke or the Emperor, perhaps, or Imperial intelligence.", fx = {} },
	[6] = { text = "Ancient Technology: You have something older than the Imperium, or even something older than humanity.", fx = { NOTE("Ancient technology (the referee decides what it is)") } },
};

-- Pre-Career Events Table (2D).
PRECAREER_EVENTS = {
	[2] = { text = "You are approached by an underground (and highly illegal) psionic group who sense potential in you. You may test your PSI and attempt to enter the Psion career in any subsequent term.", fx = { { "psitest" } } },
	[3] = { text = "Your time in education is not a happy one and you suffer a deep tragedy, perhaps you become hopelessly addicted to drink or drugs, a failed romance leaves you in tatters, or a fatal accident involving a close friend shakes your confidence. You crash and fail to graduate.", fx = { { "nograd" } } },
	[4] = { text = "A supposedly harmless prank goes wrong and someone gets hurt, physically or emotionally. Roll SOC 8+. If you succeed, gain a Rival. If you fail, gain an Enemy. If you roll 2, you must take the Prisoner career in your next term.", fx = { CHK({ "SOC" }, 8, { { "assoc", "rival", 1 } }, { { "assoc", "enemy", 1 } }, { { "assoc", "enemy", 1 }, { "prisoner" } }) } },
	[5] = { text = "Taking advantage of youth, you party as much as you study. Gain Carouse 1.", fx = { G("Carouse", 1) } },
	[6] = { text = "You become involved in a tightly knit clique or group and make a pact to remain friends forever, wherever in the galaxy you may end. Gain D3 Allies.", fx = { { "assoc", "ally", "D3" } } },
	[7] = { text = "Life Event. Roll on the Life Events table.", fx = { { "life" } } },
	[8] = { text = "You join a political movement. Roll SOC 8+. If successful, you become a leading figure. Gain one Ally within the movement but gain one Enemy in wider society.", fx = { CHK({ "SOC" }, 8, { { "assoc", "ally", 1 }, { "assoc", "enemy", 1 } }, {}) } },
	[9] = { text = "You develop a healthy interest in a hobby or other area of study. Gain any skill of your choice, with the exception of Jack-of-all-Trades, at level 0.", fx = { { "gainany", 0, nojoat = true } } },
	[10] = { text = "A newly arrived tutor rubs you up the wrong way and you work hard to overturn their conclusions. Roll 9+ on any skill you have learned during this term. If successful, you provide a truly elegant proof that soon becomes accepted as the standard approach. Gain a level in the skill you rolled on and the tutor as a Rival.", fx = { CHK({ "$termskill" }, 9, { { "raiserolled" }, { "assoc", "rival", 1 } }, {}) } },
	[11] = { text = "War comes and a wide-ranging draft is instigated. You can either flee and join the Drifter career next term or be drafted (roll 1D: 1-3 Army, 4-5 Marine, 6 Navy). Either way, you do not graduate this term. However, if you roll SOC 9+, you can get enough strings pulled to avoid the draft and complete your education - you may attempt graduation normally and are not drafted.", fx = { { "wardraft" } } },
	[12] = { text = "You gain wide-ranging recognition of your initiative and innovative approach to study. Increase your SOC by +1.", fx = { { "stat", "soc", 1 } } },
};

-- Values that differ between the 2016 Core Rulebook and the Core Rulebook
-- Update 2022 (pages 16 and 49 of the Update). Chosen by the GM's option
-- "Rules printing" (TCWIZ_RULES); everything else follows the loaded book.
RULES = {
	["2016"] = { uniEntry = 7, uniGrad = 7, uniHonours = 11, uniGradEdu = 2,
		academy = { army = 8, marine = 9, navy = 9 }, academyGrad = 8, academyHonours = 11, anagathicsCost = 200000 },
	["2022"] = { uniEntry = 6, uniGrad = 6, uniHonours = 10, uniGradEdu = 1,
		academy = { army = 7, marine = 8, navy = 8 }, academyGrad = 7, academyHonours = 11, anagathicsCost = 25000 },
};

-- Pre-career education.
UNIVERSITY = {
	name = "University",
	text = "Most worlds have one or more universities. A university education will channel a character's efforts into a narrow range of skills but there are few other ways to become more skilful within them so quickly.",
	entry = { "edu", 7 },
	skills = { "Admin", "Advocate", "Animals (training)", "Animals (veterinary)", "Art", "Astrogation", "Electronics", "Engineer", "Language", "Medic", "Navigation", "Profession", "Science" },
	careerdm = { "agent", "army", "citizen:corporate", "entertainer:journalist", "marine", "navy", "scholar", "scout" },
};
ACADEMIES = {
	army = { name = "Military Academy (Army)", entry = { "end", 8 } },
	marine = { name = "Military Academy (Marines)", entry = { "end", 9 } },
	navy = { name = "Military Academy (Navy)", entry = { "int", 9 } },
};

-- Skill Packages (the group chooses one; each Traveller takes turns picking from it).
SKILL_PACKAGES = {
	{ name = "Traveller", text = "An all-round skill package, good for a campaign where the Travellers are trading one week and blowing things up the next.", skills = { "Pilot 1", "Deception 1", "Electronics 1", "Gunner 1", "Gun Combat 1", "Persuade 1", "Stealth 1", "Medic 1" } },
	{ name = "Explorer", text = "For campaigns where the Travellers are operating on the fringe of Charted Space, dealing with new worlds and ancient relics.", skills = { "Pilot 1", "Astrogation 1", "Electronics 1", "Survival 1", "Recon 1", "Gun Combat 1", "Stealth 1", "Medic 1" } },
	{ name = "Mercenary", text = "Focuses on ground combat and is aimed at combat-heavy games.", skills = { "Electronics 1", "Medic 1", "Leadership 1", "Heavy Weapons 1", "Gun Combat 1", "Gun Combat 1", "Stealth 1", "Recon 1" } },
	{ name = "Diplomat", text = "For campaigns where the Travellers are government operatives and ambassadors.", skills = { "Advocate 1", "Diplomat 1", "Persuade 1", "Stealth 1", "Streetwise 1", "Deception 1", "Electronics 1", "Admin 1" } },
	{ name = "Trader", text = "For campaigns where trading and commerce are the primary activities of the Travellers.", skills = { "Pilot 1", "Electronics 1", "Medic 1", "Streetwise 1", "Broker 1", "Advocate 1", "Diplomat 1", "Astrogation 1" } },
	{ name = "Investigator", text = "For campaigns centering on solving crimes and investigating mysteries.", skills = { "Advocate 1", "Admin 1", "Investigate 1", "Persuade 1", "Stealth 1", "Streetwise 1", "Electronics 1", "Deception 1", "Gun Combat 1" } },
	{ name = "Starship", text = "For campaigns where the Travellers will spend almost all their time on spacecraft.", skills = { "Pilot 1", "Gunner 1", "Engineer 1", "Mechanic 1", "Electronics 1", "Medic 1", "Tactics (naval) 1", "Astrogation 1" } },
	{ name = "Criminal", text = "For campaigns involving crime and elaborate heists.", skills = { "Pilot 1", "Electronics 1", "Stealth 1", "Deception 1", "Persuade 1", "Streetwise 1", "Broker 1", "Medic 1" } },
};

-- Material benefits named in the careers' Benefits columns (Benefits, p. 44).
-- kind: item (pick gear within a cost and TL limit), ship, shares, tas, assoc, stat.
BENEFITS = {
	["Armour"] = { kind = "item", itemtype = "armour", limit = 10000, tl = 12, again = "Another armour (Cr10000, TL12), or trade the first in for armour up to Cr25000" },
	["Blade"] = { kind = "item", itemtype = "blade", limit = 1000, tl = 12, again = "Another blade, or one level of Melee (blade)", againskill = "Melee (blade)" },
	["Combat Implant"] = { kind = "item", itemtype = "implant", limit = 50000, tl = 12, again = "A different augmentation, or one more level of the one you have" },
	["Gun"] = { kind = "item", itemtype = "gun", limit = 1000, tl = 12, again = "Another gun, or one level of the Gun Combat skill for a gun already received", againskill = "Gun Combat" },
	["Weapon"] = { kind = "item", itemtype = "weapon", limit = 1000, tl = 12, again = "Another weapon, or one level of the Melee or Gun Combat skill for a weapon already received", againskill = "Melee or Gun Combat" },
	["Scientific Equipment"] = { kind = "item", itemtype = "science", limit = 2000, tl = 12, again = "Another piece of scientific equipment, or one level of Electronics or Science", againskill = "Electronics or Science" },
	["Personal Vehicle"] = { kind = "item", itemtype = "vehicle", limit = 300000, tl = 10, again = "One level of Drive or Flyer", againskill = "Drive or Flyer", againonly = true },
	["Ship's Boat"] = { kind = "ship", ship = "Ship's Boat (or other small craft up to MCr10, TL12)", again = "Pilot (small craft)", againskill = "Pilot (small craft)", againonly = true },
	["Free Trader"] = { kind = "ship", ship = "Free Trader (or Far Trader)", mortgage = 25 },
	["Lab Ship"] = { kind = "ship", ship = "Lab Ship", mortgage = 25 },
	["Yacht"] = { kind = "ship", ship = "Yacht (or Safari Ship)", mortgage = 25 },
	["Scout Ship"] = { kind = "ship", ship = "Scout Ship (Scout Service reserve)", reroll = true },
	["TAS Membership"] = { kind = "tas" },
	["Ship Share"] = { kind = "shares", n = 1 },
	["Ally"] = { kind = "assoc", assoc = "ally" },
	["Contact"] = { kind = "assoc", assoc = "contact" },
};

-- Careers. qual: list of { stat, target } (best of them is rolled); assignments
-- with survival and advancement; tables (1D); ranks per assignment key (or
-- "default"), "officer" for commissioned; mishaps (1D); events (2D);
-- benefits.cash and benefits.other (1D+DM, 1-7).
CAREER_ORDER = { "agent", "army", "citizen", "drifter", "entertainer", "marine", "merchant", "navy", "noble", "rogue", "scholar", "scout", "psion", "prisoner" };

CAREERS = {};

CAREERS.agent = {
	name = "Agent",
	text = "Law enforcement agencies, corporate operatives, spies, and others who work in the shadows.",
	qual = { { "int", 6 } },
	changeassign = "newcareer", medical = "civil", pension = true,
	assignments = {
		{ key = "law", name = "Law Enforcement", text = "You are a police officer or detective.", surv = { "end", 6 }, adv = { "int", 6 } },
		{ key = "intelligence", name = "Intelligence", text = "You work as a spy or saboteur.", surv = { "int", 7 }, adv = { "int", 5 } },
		{ key = "corporate", name = "Corporate", text = "You work for a corporation, spying on rival organisations.", surv = { "int", 5 }, adv = { "int", 7 } },
	},
	tables = {
		personal = { "Gun Combat", "DEX +1", "END +1", "Melee", "INT +1", "Athletics" },
		service = { "Streetwise", "Drive", "Investigate", "Flyer", "Recon", "Gun Combat" },
		advanced = { min = 8, "Advocate", "Language", "Explosives", "Medic", "Vacc Suit", "Electronics" },
		law = { "Investigate", "Recon", "Streetwise", "Stealth", "Melee", "Advocate" },
		intelligence = { "Investigate", "Recon", "Electronics (comms)", "Stealth", "Persuade", "Deception" },
		corporate = { "Investigate", "Electronics (computers)", "Stealth", "Carouse", "Deception", "Streetwise" },
	},
	ranks = {
		law = { [0] = { "Rookie" }, { "Corporal", "Streetwise 1" }, { "Sergeant" }, { "Detective" }, { "Lieutenant", "Investigate 1" }, { "Chief", "Admin 1" }, { "Commissioner", "SOC +1" } },
		default = { [0] = { "" }, { "Agent", "Deception 1" }, { "Field Agent", "Investigate 1" }, { "" }, { "Special Agent", "Gun Combat 1" }, { "Assistant Director" }, { "Director" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "A criminal or other figure under investigation offers you a deal. Accept, and you leave this career without further penalty (although you lose the Benefit roll as normal). Refuse, and you must roll twice on the Injury Table and take the lower result. You gain an Enemy and one level in any skill you choose.",
			fx = { CH(OPT("Accept the deal", {}), OPT("Refuse", { { "injury", "lower" }, { "assoc", "enemy", 1 }, { "gainany" } })) } },
		{ text = "An investigation goes critically wrong or leads to the top, ruining your career. Roll Advocate 8+. If you succeed, you may keep the Benefit roll from this term. If you roll 2, you must take the Prisoner career in your next term.",
			fx = { CHK({ "Advocate" }, 8, { { "bkeep" } }, {}, { { "prisoner" } }) } },
		{ text = "You learn something you should not know, and people want to kill you for it. Gain an Enemy and Deception 1.", fx = { { "assoc", "enemy", 1 }, G("Deception", 1) } },
		{ text = "Your work ends up coming home with you, and someone gets hurt. Choose one of your Contacts, Allies or family members, and roll twice on the Injury Table for them, taking the lower result.", fx = { { "injuryother" } } },
		{ text = "Injured. Roll on the Injury Table.", fx = { { "injury" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "An investigation takes on a dangerous turn. Roll Investigate 8+ or Streetwise 8+. If you fail, roll on the Mishap Table. If you succeed, increase one of these skills by one level: Deception, Jack-of-all-Trades, Persuade or Tactics.",
			fx = { CHK({ "Investigate", "Streetwise" }, 8, { PICK("Deception", "Jack-of-all-Trades", "Persuade", "Tactics") }, { { "mishap" } }) } },
		[4] = { text = "You complete a mission for your superiors, and are suitably rewarded. Gain DM+1 to any one Benefit roll from this career.", fx = { { "bdm", 1 } } },
		[5] = { text = "You establish a network of contacts. Gain D3 Contacts.", fx = { { "assoc", "contact", "D3" } } },
		[6] = { text = "You are given advanced training in a specialist field. Roll EDU 8+ to increase any one skill you already have by one level.", fx = { CHK({ "EDU" }, 8, { { "gainany", nil, have = true } }, {}) } },
		[7] = LIFE,
		[8] = { text = "You go undercover to investigate an enemy. Roll Deception 8+. If you succeed, roll immediately on the Rogue or Citizen Events Table and make one roll on any Specialist skill table for that career. If you fail, roll immediately on the Rogue or Citizen Mishap Table.",
			fx = { CHK({ "Deception" }, 8, { { "undercover", ok = true } }, { { "undercover", ok = false } }) } },
		[9] = { text = "You go above and beyond the call of duty. Gain DM+2 to your next Advancement check.", fx = { { "adm", 2 } } },
		[10] = { text = "You are given specialist training in vehicles. Gain one of Drive 1, Flyer 1, Pilot 1 or Gunner 1.", fx = { PICK("Drive 1", "Flyer 1", "Pilot 1", "Gunner 1") } },
		[11] = { text = "You are befriended by a senior agent. Either increase Investigate by one level or DM+4 to an Advancement roll thanks to their aid.", fx = { CH(OPT("Investigate +1", { G("Investigate") }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "Your efforts uncover a major conspiracy against your employers. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 1000, 2000, 5000, 7500, 10000, 25000, 50000 },
		other = { "Scientific Equipment", "INT +1", "Ship Share", "Weapon", "Combat Implant", "SOC +1 or Combat Implant", "TAS Membership" },
	},
};

CAREERS.army = {
	name = "Army",
	text = "Members of the planetary armed fighting forces. Soldiers deal with planetary surface actions, battles, and campaigns. Such individuals may also be mercenaries for hire.",
	qual = { { "end", 5 } }, agedm = { 30, -2 },
	commission = { "soc", 8 },
	changeassign = "qual", medical = "military", pension = true,
	assignments = {
		{ key = "support", name = "Support", text = "You were an engineer, technician, medic, cook or in some other role behind the front lines.", surv = { "end", 5 }, adv = { "edu", 7 } },
		{ key = "infantry", name = "Infantry", text = "You were one of the Poor Bloody Infantry on the ground.", surv = { "str", 6 }, adv = { "edu", 6 } },
		{ key = "cavalry", name = "Cavalry", text = "You are one of the crew of a gunship or tank.", surv = { "int", 7 }, adv = { "int", 5 } },
	},
	tables = {
		personal = { "STR +1", "DEX +1", "END +1", "Gambler", "Medic", "Melee" },
		service = { "Drive or Vacc Suit", "Athletics", "Gun Combat", "Recon", "Melee", "Heavy Weapons" },
		advanced = { min = 8, "Tactics (military)", "Electronics", "Navigation", "Explosives", "Engineer", "Survival" },
		officer = { "Tactics (military)", "Leadership", "Advocate", "Diplomat", "Electronics", "Admin" },
		support = { "Mechanic", "Drive or Flyer", "Profession", "Explosives", "Electronics (comms)", "Medic" },
		infantry = { "Gun Combat", "Melee", "Heavy Weapons", "Stealth", "Athletics", "Recon" },
		cavalry = { "Mechanic", "Drive", "Flyer", "Recon", "Heavy Weapons (vehicle)", "Electronics (sensors)" },
	},
	ranks = {
		default = { [0] = { "Private", "Gun Combat 1" }, { "Lance Corporal", "Recon 1" }, { "Corporal" }, { "Lance Sergeant", "Leadership 1" }, { "Sergeant" }, { "Gunnery Sergeant" }, { "Sergeant Major" } },
		officer = { { "Lieutenant", "Leadership 1" }, { "Captain" }, { "Major", "Tactics (military) 1" }, { "Lt Colonel" }, { "Colonel" }, { "General", { { "socmin", 10 } } } },
	},
	mishaps = {
		{ text = "Severely injured in action (this is the same as a result of 2 on the Injury Table). Alternatively, roll twice on the Injury Table and take the lower result.", fx = { SEVERE } },
		{ text = "Your unit is slaughtered in a disastrous battle, for which you blame your commander. Gain them as an Enemy as they have you removed from the service.", fx = { { "assoc", "enemy", 1 } } },
		{ text = "You are sent to a very unpleasant region (jungle, swamp, desert, icecap, urban) to battle against guerrilla fighters and rebels. You are discharged because of stress, injury or because the government wishes to bury the whole incident. Increase Recon or Survival by one level but also gain the rebels as an Enemy.",
			fx = { PICK("Recon", "Survival"), { "assoc", "enemy", 1 } } },
		{ text = "You discover that your commanding officer is engaged in some illegal activity, such as weapon smuggling. You can join their ring and gain them as an Ally before the inevitable investigation gets you discharged, or you can cooperate with the military police - the official whitewash gets you discharged anyway but you may keep your Benefit roll from this term of service.",
			fx = { CH(OPT("Join their ring (gain an Ally)", { { "assoc", "ally", 1 } }), OPT("Cooperate with the military police (keep this term's Benefit roll)", { { "bkeep" } })) } },
		{ text = "You are tormented by or quarrel with an officer or fellow soldier. Gain that officer as a Rival as they drive you out of the service.", fx = { { "assoc", "rival", 1 } } },
		{ text = "Injured. Roll on the Injury Table.", fx = { { "injury" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "You are assigned to a planet with a hostile or wild environment. Gain one of Vacc Suit 1, Engineer 1, Animals (riding or training) 1 or Recon 1.", fx = { PICK("Vacc Suit 1", "Engineer 1", "Animals (riding) 1", "Animals (training) 1", "Recon 1") } },
		[4] = { text = "You are assigned to an urbanised planet torn by war. Gain one of Stealth 1, Streetwise 1, Persuade 1 or Recon 1.", fx = { PICK("Stealth 1", "Streetwise 1", "Persuade 1", "Recon 1") } },
		[5] = { text = "You are given a special assignment or duty in your unit. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[6] = { text = "You are thrown into a brutal ground war. Roll EDU 8+ to avoid injury, if you succeed, you gain one level in Gun Combat or Leadership.", fx = { CHK({ "EDU" }, 8, { PICK("Gun Combat", "Leadership") }, { { "injury" } }) } },
		[7] = LIFE,
		[8] = { text = "You are given advanced training in a specialist field. Roll EDU 8+ to increase any one skill you already have by one level.", fx = { CHK({ "EDU" }, 8, { { "gainany", nil, have = true } }, {}) } },
		[9] = { text = "Surrounded and outnumbered by the enemy, you hold out until relief arrives. Gain DM+2 to your next Advancement check.", fx = { { "adm", 2 } } },
		[10] = { text = "You are assigned to a peacekeeping role. Gain one of Admin 1, Investigate 1, Deception 1 or Recon 1.", fx = { PICK("Admin 1", "Investigate 1", "Deception 1", "Recon 1") } },
		[11] = { text = "Your commanding officer takes an interest in your career. Either gain Tactics (military) 1 or DM+4 to your next Advancement roll thanks to their aid.", fx = { CH(OPT("Tactics (military) 1", { G("Tactics (military)", 1) }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "You display heroism in battle. You may gain a promotion or a commission automatically.", fx = { { "promoteorcomm" } } },
	},
	benefits = {
		cash = { 2000, 5000, 10000, 10000, 10000, 20000, 30000 },
		other = { "Combat Implant", "INT +1", "EDU +1", "Weapon", "Armour", "END +1 or Combat Implant", "SOC +1" },
	},
};

CAREERS.citizen = {
	name = "Citizen",
	text = "Individuals serving in a corporation, bureaucracy or industry, or who are making a new life on an untamed planet.",
	qual = { { "edu", 5 } },
	changeassign = "newcareer", medical = "civil", pension = true, basic = "assignment",
	assignments = {
		{ key = "corporate", name = "Corporate", text = "You are an executive or manager in a large corporation.", surv = { "soc", 6 }, adv = { "int", 6 } },
		{ key = "worker", name = "Worker", text = "You are a blue collar worker on an industrial world.", surv = { "end", 4 }, adv = { "edu", 8 } },
		{ key = "colonist", name = "Colonist", text = "You are building a new life on a recently settled world that still needs taming.", surv = { "int", 7 }, adv = { "end", 5 } },
	},
	tables = {
		personal = { "EDU +1", "INT +1", "Carouse", "Gambler", "Drive", "Jack-of-all-Trades" },
		service = { "Drive", "Flyer", "Streetwise", "Melee", "Steward", "Profession" },
		advanced = { min = 10, "Art", "Advocate", "Diplomat", "Language", "Electronics (computers)", "Medic" },
		corporate = { "Advocate", "Admin", "Broker", "Electronics (computers)", "Diplomat", "Leadership" },
		worker = { "Drive", "Mechanic", "Electronics", "Engineer", "Profession", "Science" },
		colonist = { "Animals", "Athletics", "Jack-of-all-Trades", "Drive", "Survival", "Recon" },
	},
	ranks = {
		corporate = { [0] = { "" }, { "" }, { "Manager", "Admin 1" }, { "" }, { "Senior Manager", "Advocate 1" }, { "" }, { "Director", "SOC +1" } },
		worker = { [0] = { "" }, { "" }, { "Technician", "Profession 1" }, { "" }, { "Craftsman", "Mechanic 1" }, { "" }, { "Master Technician", "Engineer 1" } },
		colonist = { [0] = { "" }, { "" }, { "Settler", "Survival 1" }, { "" }, { "Explorer", "Navigation 1" }, { "" }, { "", "Gun Combat 1" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "You are harassed and your life ruined by a criminal gang. Gain the gang as an Enemy.", fx = { { "assoc", "enemy", 1 } } },
		{ text = "Hard times caused by a lack of interstellar trade costs you your job. Lose one SOC.", fx = { { "stat", "soc", -1 } } },
		{ text = "Your business is investigated by the planetary authorities (or your colony suffers interference from interests offworld). Co-operate, and the business or colony is shut down, but you gain DM+2 to the Qualification check for your next career as a reward for your aid. Refuse, and gain an Ally.",
			fx = { CH(OPT("Co-operate (DM+2 to your next Qualification roll)", { { "qdm", 2 } }), OPT("Refuse (gain an Ally)", { { "assoc", "ally", 1 } })) } },
		{ text = "A revolution, attack or other unusual event throws your life into chaos, forcing you to leave the planet. Roll Streetwise 8+. If you succeed, increase any skill you have by one level.", fx = { CHK({ "Streetwise" }, 8, { { "gainany", nil, have = true } }, {}) } },
		{ text = "Injured. Roll on the Injury Table.", fx = { { "injury" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "Political upheaval strikes your homeworld, and you are caught up in the revolution. Gain either Advocate 1, Persuade 1, Explosives 1 or Streetwise 1. Roll whichever skill you chose 8+. If you succeed you come out on the winning side, and gain DM+2 to your next Advancement roll. Fail, and you suffer DM-2 to your next Survival roll.",
			fx = { PICK("Advocate 1", "Persuade 1", "Explosives 1", "Streetwise 1"), CHK({ "$picked" }, 8, { { "adm", 2 } }, { { "sdm", -2 } }) } },
		[4] = { text = "You spend time maintaining and using heavy vehicles, either as part of your job or as a hobby. Increase Mechanic, Drive, Electronics, Flyer or Engineer by one level.", fx = { PICK("Mechanic", "Drive", "Electronics", "Flyer", "Engineer") } },
		[5] = { text = "Your business expands, your corporation grows, or the colony thrives. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[6] = { text = "You are given advanced training in a specialist field. Roll EDU 10+ to gain any one skill of your choice at level 1.", fx = { CHK({ "EDU" }, 10, { { "gainany", 1 } }, {}) } },
		[7] = LIFE,
		[8] = { text = "You learn something you should not have - a corporate secret, a political scandal - which you can profit from illegally. If you choose to do so, then you gain DM+1 to a Benefit roll from this career and gain Streetwise 1, Deception 1 or a criminal Contact. If you refuse, you gain nothing.",
			fx = { CH(OPT("Profit from it", { { "bdm", 1 }, PICK("Streetwise 1", "Deception 1", "Contact") }), OPT("Refuse", {})) } },
		[9] = { text = "You are rewarded for your diligence or cunning. Gain DM+2 to your next Advancement check.", fx = { { "adm", 2 } } },
		[10] = { text = "You gain experience in a technical field as a computer operator or surveyor. Increase Electronics or Engineer by one level.", fx = { PICK("Electronics", "Engineer") } },
		[11] = { text = "You befriend a superior in the corporation or the colony. Gain an Ally. Either gain Diplomat 1 or DM+4 to your next Advancement roll thanks to their aid.", fx = { { "assoc", "ally", 1 }, CH(OPT("Diplomat 1", { G("Diplomat", 1) }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "You rise to a position of power in your colony or corporation. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 2000, 5000, 10000, 10000, 10000, 50000, 100000 },
		other = { "Ship Share", "Ally", "INT +1", "Gun", "EDU +1", "Two Ship Shares", "TAS Membership" },
	},
};

CAREERS.drifter = {
	name = "Drifter",
	text = "Wanderers, hitchhikers and travellers, drifters are those who roam the stars without obvious purpose or direction.",
	qual = {}, autoqual = true,
	changeassign = "qual", medical = "rough", pension = false, basic = "assignment",
	assignments = {
		{ key = "barbarian", name = "Barbarian", text = "You live on a primitive world without the benefits of technology.", surv = { "end", 7 }, adv = { "str", 7 } },
		{ key = "wanderer", name = "Wanderer", text = "You are a space bum, living hand-to-mouth in slums and spaceports across the galaxy.", surv = { "end", 7 }, adv = { "int", 7 } },
		{ key = "scavenger", name = "Scavenger", text = "You work as a belter (asteroid miner) or on a salvage crew.", surv = { "dex", 7 }, adv = { "end", 7 } },
	},
	tables = {
		personal = { "STR +1", "END +1", "DEX +1", "Language", "Profession", "Jack-of-all-Trades" },
		service = { "Athletics", "Melee (unarmed)", "Recon", "Streetwise", "Stealth", "Survival" },
		barbarian = { "Animals", "Carouse", "Melee (blade)", "Stealth", "Seafarer (personal) or Seafarer (sail)", "Survival" },
		wanderer = { "Drive", "Deception", "Recon", "Stealth", "Streetwise", "Survival" },
		scavenger = { "Pilot (small craft)", "Mechanic", "Astrogation", "Vacc Suit", "Profession", "Gun Combat" },
	},
	ranks = {
		barbarian = { [0] = { "" }, { "", "Survival 1" }, { "Warrior", "Melee (blade) 1" }, { "" }, { "Chieftain", "Leadership 1" }, { "" }, { "Warlord" } },
		wanderer = { [0] = { "" }, { "", "Streetwise 1" }, { "" }, { "", "Deception 1" }, { "" }, { "" }, { "" } },
		scavenger = { [0] = { "" }, { "", "Vacc Suit 1" }, { "" }, { "", "Profession (belter) 1 or Mechanic 1" }, { "" }, { "" }, { "" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "Injured. Roll on the Injury Table.", fx = { { "injury" } } },
		{ text = "You run afoul of a criminal gang, corrupt bureaucrat or other foe. Gain an Enemy.", fx = { { "assoc", "enemy", 1 } } },
		{ text = "You suffer from a life-threatening illness. Reduce your END by 1.", fx = { { "stat", "end", -1 } } },
		{ text = "Betrayed by a friend. One of your Contacts or Allies betrays you, ending your career. That Contact or Ally becomes a Rival or Enemy. If you have no Contacts or Allies, then you are betrayed by someone you never saw coming and still gain a Rival or Enemy. In addition, roll 2D. If you roll 2, you must take the Prisoner career in your next term.",
			fx = { BETRAYED, { "prisoner2" } } },
		{ text = "You do not know what happened to you. There is a gap in your memory.", fx = {} },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "A patron offers you a chance at a job. If you accept, you gain DM+4 to your next Qualification roll, but you owe that patron a favour.", fx = { CH(OPT("Accept (DM+4 to your next Qualification roll; you owe a favour)", { { "qdm", 4 }, NOTE("Owes a patron a favour") }), OPT("Decline", {})) } },
		[4] = { text = "You pick up a few useful skills here and there. Gain one level of Jack-of-all-Trades, Survival, Streetwise or Melee (any).", fx = { PICK("Jack-of-all-Trades", "Survival", "Streetwise", "Melee") } },
		[5] = { text = "You manage to scavenge something of use. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[6] = { text = "You encounter something unusual. Go to the Life Events Table and have an Unusual Event.", fx = { { "unusual" } } },
		[7] = LIFE,
		[8] = { text = "You are attacked by enemies. Gain an Enemy if you do not have one already, and roll either Melee 8+, Gun Combat 8+ or Stealth 8+ to avoid a roll on the Injury Table.", fx = { { "assoc", "enemy", 1, ifnone = true }, CHK({ "Melee", "Gun Combat", "Stealth" }, 8, {}, { { "injury" } }) } },
		[9] = { text = "You are offered a chance to take part in a risky but rewarding adventure. If you accept, roll 1D: On a 1-2, you are injured or arrested, either roll on the Injury Table or take the Prisoner career in your next term. On 3-4, you survive, but gain nothing. On a 5-6, you succeed. Gain DM+4 to one Benefit roll.",
			fx = { CH(OPT("Accept the adventure", { { "t1d", { { 1, 2, { CH(OPT("Roll on the Injury Table", { { "injury" } }), OPT("Take the Prisoner career next term", { { "prisoner" } })) } }, { 3, 4, {} }, { 5, 6, { { "bdm", 4 } } } } } }), OPT("Decline", {})) } },
		[10] = { text = "Life on the edge hones your abilities. Increase any skill you already have by one level.", fx = { { "gainany", nil, have = true } } },
		[11] = { text = "You are forcibly drafted. Roll for the Draft next term.", fx = { { "draft" } } },
		[12] = { text = "You thrive on adversity. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 0, 0, 1000, 2000, 3000, 4000, 8000 },
		other = { "Contact", "Weapon", "Ally", "Weapon", "EDU +1", "Ship Share", "Two Ship Shares" },
	},
};

CAREERS.entertainer = {
	name = "Entertainer",
	text = "Individuals who are involved with the media, whether as reporters, artists or celebrities.",
	qual = { { "dex", 5 }, { "int", 5 } },
	changeassign = "newcareer", medical = "civil", pension = true,
	assignments = {
		{ key = "artist", name = "Artist", text = "You are a writer, holographer or other creative.", surv = { "soc", 6 }, adv = { "int", 6 } },
		{ key = "journalist", name = "Journalist", text = "You report on local or galactic events for a news feed, the TAS or other organisation.", surv = { "edu", 7 }, adv = { "int", 5 } },
		{ key = "performer", name = "Performer", text = "You are an actor, dancer, acrobat, professional athlete or other public performer.", surv = { "int", 5 }, adv = { "dex", 7 } },
	},
	tables = {
		personal = { "DEX +1", "INT +1", "SOC +1", "Language", "Carouse", "Jack-of-all-Trades" },
		service = { "Art", "Carouse", "Deception", "Drive", "Persuade", "Steward" },
		advanced = { min = 10, "Advocate", "Broker", "Deception", "Science", "Streetwise", "Diplomat" },
		artist = { "Art", "Carouse", "Electronics (computers)", "Gambler", "Persuade", "Profession" },
		journalist = { "Art (holography) or Art (write)", "Electronics", "Drive", "Investigate", "Recon", "Streetwise" },
		performer = { "Art (performer) or Art (instrument)", "Athletics", "Carouse", "Deception", "Stealth", "Streetwise" },
	},
	ranks = {
		artist = { [0] = { "" }, { "", "Art 1" }, { "" }, { "", "Investigate 1" }, { "" }, { "Famous Artist", "SOC +1" }, { "" } },
		journalist = { [0] = { "" }, { "Freelancer", "Electronics (comms) 1" }, { "Staff Writer", "Investigate 1" }, { "" }, { "Correspondent", "Persuade 1" }, { "" }, { "Senior Correspondent", "SOC +1" } },
		performer = { [0] = { "" }, { "", "DEX +1" }, { "" }, { "", "STR +1" }, { "" }, { "Famous Performer", "SOC +1" }, { "" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "You expose or are involved in a scandal of some sort.", fx = {} },
		{ text = "Public opinion turns on you. Reduce your SOC by 1.", fx = { { "stat", "soc", -1 } } },
		{ text = "You are betrayed by a peer. One of your Contacts or Allies betrays you, ending your career. That Contact or Ally becomes a Rival or Enemy. If you have no Contacts or Allies, then you are betrayed by someone you never saw coming and still gain a Rival or Enemy.", fx = { BETRAYED } },
		{ text = "An investigation, tour, project or expedition goes wrong, stranding you far from home. Gain one of Survival 1, Pilot 1, Persuade 1 or Streetwise 1.", fx = { PICK("Survival 1", "Pilot 1", "Persuade 1", "Streetwise 1") } },
		{ text = "You are forced out because of censorship or controversy. What truth did you get too close to? You gain DM+2 to the Qualification roll for your next career.", fx = { { "qdm", 2 } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "You are invited to take part in a controversial event or exhibition. Roll Art or Investigate 8+. If you succeed, gain one SOC. If you fail, lose one SOC.", fx = { CHK({ "Art", "Investigate" }, 8, { { "stat", "soc", 1 } }, { { "stat", "soc", -1 } }) } },
		[4] = { text = "You are a part of your homeworld's celebrity circles. Gain one of Carouse 1, Persuade 1, Steward 1 or a Contact.", fx = { PICK("Carouse 1", "Persuade 1", "Steward 1", "Contact") } },
		[5] = { text = "One of your works is especially well received and popular, making you a minor celebrity. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[6] = { text = "You gain a patron in the arts. Gain DM+2 to your next Advancement check and an Ally.", fx = { { "adm", 2 }, { "assoc", "ally", 1 } } },
		[7] = LIFE,
		[8] = { text = "You have the opportunity to criticise or even bring down a questionable political leader on your homeworld. If you refuse and support the leader, you gain nothing. If you accept, gain an Enemy and roll Art or Persuade 8+. If you succeed, gain one level in any skill you already have. If you fail, increase a skill anyway and roll on the Mishap table.",
			fx = { CH(OPT("Accept", { { "assoc", "enemy", 1 }, CHK({ "Art", "Persuade" }, 8, { { "gainany", nil, have = true } }, { { "gainany", nil, have = true }, { "mishap" } }) }), OPT("Refuse and support the leader", {})) } },
		[9] = { text = "You go on a tour of the sector, visiting several worlds. Gain D3 Contacts.", fx = { { "assoc", "contact", "D3" } } },
		[10] = { text = "One of your pieces of art is stolen, and the investigation brings you into the criminal underworld. Gain one of Streetwise 1, Investigate 1, Recon 1 or Stealth 1.", fx = { PICK("Streetwise 1", "Investigate 1", "Recon 1", "Stealth 1") } },
		[11] = { text = "As an artist, you lead a strange and charmed life. Go to the Life Events Table and have an Unusual Event.", fx = { { "unusual" } } },
		[12] = { text = "You win a prestigious prize. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 0, 0, 10000, 10000, 40000, 40000, 80000 },
		other = { "Contact", "SOC +1", "Contact", "SOC +1", "INT +1", "Two Ship Shares", "SOC +1 and EDU +1" },
	},
};

CAREERS.marine = {
	name = "Marine",
	text = "Members of the armed fighting forces carried aboard starships, marines deal with piracy and boarding actions in space, defend the starports and bases belonging to the navy and supplement ground forces such as the army.",
	qual = { { "end", 6 } }, agedm = { 30, -2 },
	commission = { "soc", 8 },
	changeassign = "qual", medical = "military", pension = true,
	assignments = {
		{ key = "support", name = "Support", text = "You are a quartermaster, engineer or battlefield medic in the marines.", surv = { "end", 5 }, adv = { "edu", 7 } },
		{ key = "starmarine", name = "Star Marine", text = "You are trained to fight boarding actions and capture enemy vessels.", surv = { "end", 6 }, adv = { "edu", 6 } },
		{ key = "groundassault", name = "Ground Assault", text = "You are kicked out of a spacecraft in high orbit and told to 'capture that planet'.", surv = { "end", 7 }, adv = { "edu", 5 } },
	},
	tables = {
		personal = { "STR +1", "DEX +1", "END +1", "Gambler", "Melee (unarmed)", "Melee (blade)" },
		service = { "Athletics", "Vacc Suit", "Tactics", "Heavy Weapons", "Gun Combat", "Stealth" },
		advanced = { min = 8, "Medic", "Survival", "Explosives", "Engineer", "Pilot", "Navigation" },
		officer = { "Electronics", "Tactics", "Admin", "Advocate", "Vacc Suit", "Leadership" },
		support = { "Electronics", "Mechanic", "Drive or Flyer", "Medic", "Heavy Weapons", "Gun Combat" },
		starmarine = { "Vacc Suit", "Athletics", "Gunner", "Melee (blade)", "Electronics", "Gun Combat" },
		groundassault = { "Vacc Suit", "Heavy Weapons", "Recon", "Melee (blade)", "Tactics (military)", "Gun Combat" },
	},
	ranks = {
		default = { [0] = { "Marine", "Gun Combat 1 or Melee (blade) 1" }, { "Lance Corporal", "Gun Combat 1" }, { "Corporal" }, { "Lance Sergeant", "Leadership 1" }, { "Sergeant" }, { "Gunnery Sergeant", "END +1" }, { "Sergeant Major" } },
		officer = { { "Lieutenant", "Leadership 1" }, { "Captain" }, { "Force Commander", "Tactics 1" }, { "Lieutenant Colonel" }, { "Colonel", { { "socmin", 10 } } }, { "Brigadier" } },
	},
	mishaps = {
		{ text = "Severely injured in action (this is the same as a result of 2 on the Injury Table). Alternatively, roll twice on the Injury Table and take the lower result.", fx = { SEVERE } },
		{ text = "A mission goes wrong, you and several others are captured and mistreated by the enemy. Due to your injuries, you are discharged early. Gain your jailer as an Enemy and reduce your STR and DEX by one because of your injuries.", fx = { { "assoc", "enemy", 1 }, { "stat", "str", -1 }, { "stat", "dex", -1 } } },
		{ text = "A mission goes wrong and you are stranded behind enemy lines. Increase Stealth or Survival by one level but, due to the mission's failure, you are ejected from the service.", fx = { PICK("Stealth", "Survival") } },
		{ text = "You are ordered to take part in a black ops mission that goes against your conscience. If you refuse you are ejected from the service. If you accept you may stay with the marines but gain the lone survivor as an Enemy.", fx = { CH(OPT("Accept (stay; gain an Enemy)", { { "stay" }, { "assoc", "enemy", 1 } }), OPT("Refuse (ejected)", {})) } },
		{ text = "You are tormented by or quarrel with an officer or fellow marine. Gain that character as a Rival as he drives you out of the service.", fx = { { "assoc", "rival", 1 } } },
		{ text = "Injured. Roll on the Injury Table.", fx = { { "injury" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "Trapped behind enemy lines, you have to survive on your own. Gain one of Survival 1, Stealth 1, Deception 1 or Streetwise 1.", fx = { PICK("Survival 1", "Stealth 1", "Deception 1", "Streetwise 1") } },
		[4] = { text = "You are assigned to the security staff of a space station. Increase Vacc Suit or Athletics (dexterity) by one level.", fx = { PICK("Vacc Suit", "Athletics (dexterity)") } },
		[5] = { text = "You are given advanced training in a specialist field. Roll EDU 8+ to gain any one skill of your choice at level 1.", fx = { CHK({ "EDU" }, 8, { { "gainany", 1 } }, {}) } },
		[6] = { text = "You are assigned to an assault on an enemy fortress. Roll Melee or Gun Combat 8+ and gain Tactics (military) or Leadership if you succeed. If you fail, you are injured and lose 1 point from any physical characteristic.", fx = { CHK({ "Melee", "Gun Combat" }, 8, { PICK("Tactics (military)", "Leadership") }, { { "statpick", PHYSICAL, -1 } }) } },
		[7] = LIFE,
		[8] = { text = "You are on the front lines of a planetary assault and occupation. Gain one of Recon 1, Gun Combat 1, Leadership 1 or Electronics (comms) 1.", fx = { PICK("Recon 1", "Gun Combat 1", "Leadership 1", "Electronics (comms) 1") } },
		[9] = { text = "A mission goes disastrously wrong due to your commander's error or incompetence, but you survive. If you report your commanding officer for their failure then you gain DM+2 to your next Advancement roll and gain the officer as an Enemy. If you say nothing and protect them, gain them as an Ally.",
			fx = { CH(OPT("Report them (DM+2 to Advancement, gain an Enemy)", { { "adm", 2 }, { "assoc", "enemy", 1 } }), OPT("Protect them (gain an Ally)", { { "assoc", "ally", 1 } })) } },
		[10] = { text = "You are assigned to a black ops mission. Gain DM+2 to your next Advancement roll.", fx = { { "adm", 2 } } },
		[11] = { text = "Your commanding officer takes an interest in your career. Either gain Tactics 1 or DM+4 to your next Advancement roll thanks to their aid.", fx = { CH(OPT("Tactics 1", { G("Tactics", 1) }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "You display heroism in battle. You may gain a promotion or a commission automatically.", fx = { { "promoteorcomm" } } },
	},
	benefits = {
		cash = { 2000, 5000, 5000, 10000, 20000, 30000, 40000 },
		other = { "Armour", "INT +1", "EDU +1", "Weapon", "TAS Membership", "Armour or END +1", "SOC +2" },
	},
};

CAREERS.merchant = {
	name = "Merchant",
	text = "Members of commercial enterprise. Merchants may crew the ships of the huge trading corporations, or they may work for independent free traders who carry chance cargoes and passengers between worlds.",
	qual = { { "int", 4 } },
	changeassign = "newcareer", medical = "civil", pension = true,
	assignments = {
		{ key = "marine", name = "Merchant Marine", text = "You work on one of the massive cargo haulers run by the Imperium or the megacorporations.", surv = { "edu", 5 }, adv = { "int", 7 } },
		{ key = "freetrader", name = "Free Trader", text = "You are part of the crew of a tramp trader.", surv = { "dex", 6 }, adv = { "int", 6 } },
		{ key = "broker", name = "Broker", text = "You work in a planetside brokerage or starport.", surv = { "edu", 5 }, adv = { "int", 7 } },
	},
	tables = {
		personal = { "STR +1", "DEX +1", "END +1", "INT +1", "Language", "Streetwise" },
		service = { "Drive", "Vacc Suit", "Broker", "Steward", "Electronics", "Persuade" },
		advanced = { min = 10, "Engineer", "Astrogation", "Electronics", "Pilot", "Admin", "Advocate" },
		marine = { "Pilot", "Vacc Suit", "Athletics", "Mechanic", "Engineer", "Electronics" },
		freetrader = { "Pilot (spacecraft)", "Vacc Suit", "Deception", "Mechanic", "Streetwise", "Gunner" },
		broker = { "Admin", "Advocate", "Broker", "Streetwise", "Deception", "Persuade" },
	},
	ranks = {
		marine = { [0] = { "Crewman" }, { "Senior Crewman", "Mechanic 1" }, { "4th Officer" }, { "3rd Officer" }, { "2nd Officer", "Pilot 1" }, { "1st Officer", "SOC +1" }, { "Captain" } },
		freetrader = { [0] = { "" }, { "", "Persuade 1" }, { "" }, { "Experienced Trader", "Jack-of-all-Trades 1" }, { "" }, { "" }, { "" } },
		broker = { [0] = { "" }, { "", "Broker 1" }, { "" }, { "Experienced Broker", "Streetwise 1" }, { "" }, { "" }, { "" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "You are bankrupted by a rival. You lose all Benefits from this career, and gain the other trader as a Rival.", fx = { { "bloseall" }, { "assoc", "rival", 1 } } },
		{ text = "A sudden war destroys your trade routes and contacts, forcing you to flee that region of space. Gain Gun Combat 1 or Pilot 1.", fx = { PICK("Gun Combat 1", "Pilot 1") } },
		{ text = "Your ship or starport is destroyed by criminals. Gain them as an Enemy.", fx = { { "assoc", "enemy", 1 } } },
		{ text = "Imperial trade restrictions force you out of business. You may take the Rogue career for your next term without needing to roll for qualification.", fx = { { "autoqual", "rogue" } } },
		{ text = "A series of bad deals and decisions force you into bankruptcy. You salvage what you can. You may take a Benefit roll for this term as well as any others you are entitled to.", fx = { { "bkeep" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "You are offered the opportunity to smuggle illegal items onto a planet. If you accept, roll Deception 8+ or Persuade 8+ to gain Streetwise 1 and an extra Benefit roll. If you refuse, you gain an Enemy in the criminal sphere.",
			fx = { CH(OPT("Smuggle", { CHK({ "Deception", "Persuade" }, 8, { G("Streetwise", 1), { "bextra", 1 } }, {}) }), OPT("Refuse (gain an Enemy)", { { "assoc", "enemy", 1 } })) } },
		[4] = { text = "Gain any one of these skills, reflecting your time spent dealing with suppliers and spacers: Profession 1, Electronics 1, Engineer 1, Animals 1 or Science 1.", fx = { PICK("Profession 1", "Electronics 1", "Engineer 1", "Animals 1", "Science 1") } },
		[5] = { text = "You have a chance to risk your fortune on a possibility lucrative deal. You may gamble a number of Benefit rolls and roll Gambler 8+ or Broker 8+. If you succeed, you gain half as many Benefit rolls as you risked, rounding up. If you fail, you lose all the rolls risked. Either way, gain one level in whichever skill you used.",
			fx = { { "gamble", skills = { "Gambler", "Broker" }, raise = true } } },
		[6] = { text = "You make an unexpected connection outside your normal circles. Gain a Contact.", fx = { { "assoc", "contact", 1 } } },
		[7] = LIFE,
		[8] = { text = "You are embroiled in legal trouble. Gain one of Advocate 1, Admin 1, Diplomat 1 or Investigate 1, then roll 2D. If you roll 2, you must take the Prisoner career in your next term.", fx = { PICK("Advocate 1", "Admin 1", "Diplomat 1", "Investigate 1"), { "prisoner2" } } },
		[9] = { text = "You are given advanced training in a specialist field. Roll EDU 8+ to increase any one skill you already have by one level.", fx = { CHK({ "EDU" }, 8, { { "gainany", nil, have = true } }, {}) } },
		[10] = { text = "A good deal ensures you are living the high life for a few years. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[11] = { text = "You befriend a useful ally in one sphere. Gain an Ally and either gain a level in Carouse or DM+4 to your next Advancement roll thanks to their aid.", fx = { { "assoc", "ally", 1 }, CH(OPT("Carouse +1", { G("Carouse") }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "Your business or ship thrives. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 1000, 5000, 10000, 20000, 20000, 40000, 40000 },
		other = { "Blade", "INT +1", "EDU +1", "Gun", "Ship Share", "Free Trader", "Free Trader" },
	},
};

CAREERS.navy = {
	name = "Navy",
	text = "Members of the interstellar navy which patrols space between the stars. The navy has the responsibility for the protection of society from foreign powers and lawless elements in the interstellar trade channels.",
	qual = { { "int", 6 } }, agedm = { 34, -2 },
	commission = { "soc", 8 },
	changeassign = "qual", medical = "military", pension = true,
	assignments = {
		{ key = "line", name = "Line/Crew", text = "You serve as a general crewman or officer on a ship of the line.", surv = { "int", 5 }, adv = { "edu", 7 } },
		{ key = "engineer", name = "Engineer/Gunner", text = "You serve as a specialist technician on a starship.", surv = { "int", 6 }, adv = { "edu", 6 } },
		{ key = "flight", name = "Flight", text = "You are a pilot of a shuttle, fighter or other light craft.", surv = { "dex", 7 }, adv = { "edu", 5 } },
	},
	tables = {
		personal = { "STR +1", "DEX +1", "END +1", "INT +1", "EDU +1", "SOC +1" },
		service = { "Pilot", "Vacc Suit", "Athletics", "Gunner", "Mechanic", "Gun Combat" },
		advanced = { min = 8, "Electronics", "Astrogation", "Engineer", "Drive", "Navigation", "Admin" },
		officer = { "Leadership", "Electronics", "Pilot", "Melee (blade)", "Admin", "Tactics (naval)" },
		line = { "Electronics", "Mechanic", "Gun Combat", "Flyer", "Melee", "Vacc Suit" },
		engineer = { "Engineer", "Mechanic", "Electronics", "Engineer", "Gunner", "Flyer" },
		flight = { "Pilot", "Flyer", "Gunner", "Pilot (small craft)", "Astrogation", "Electronics" },
	},
	ranks = {
		default = { [0] = { "Crewman" }, { "Able Spacehand", "Mechanic 1" }, { "Petty Officer, 3rd Class", "Vacc Suit 1" }, { "Petty Officer, 2nd Class" }, { "Petty Officer, 1st Class", "END +1" }, { "Chief Petty Officer" }, { "Master Chief" } },
		officer = { { "Ensign", "Melee (blade) 1" }, { "Sublieutenant", "Leadership 1" }, { "Lieutenant" }, { "Commander", "Tactics (naval) 1" }, { "Captain", { { "socmin", 10 } } }, { "Admiral", { { "socmin", 12 } } } },
	},
	mishaps = {
		{ text = "Severely injured in action (this is the same as a result of 2 on the Injury Table). Alternatively, roll twice on the Injury Table and take the lower result.", fx = { SEVERE } },
		{ text = "Placed in the frozen watch (cryogenically stored on board ship) and revived improperly. Reduce STR, DEX or END by 1 due to muscle wastage. You are not ejected from this career.", fx = { { "statpick", PHYSICAL, -1 }, { "stay" } } },
		{ text = "During a battle, defeat or victory depends on your actions. You must make an 8+ roll using a skill that depends on your branch: Electronics (sensors) or Gunner if you are crew, Mechanic or Vacc Suit if you are engineer/gunner, and Pilot (small craft or spacecraft) or Tactics (naval) if you are flight. If you fail, the ship suffers severe damage and you are blamed for the disaster. You are court-martialled and discharged. If you succeed, your efforts ensure that you are honourably discharged. You still leave the career, but may keep your Benefit roll from this term.",
			fx = { { "navybattle" } } },
		{ text = "You are blamed for an accident that causes the death of several crew members. If you were responsible, then you gain one free roll on the Skills and Training table before you are ejected from this career as your guilt drives you to excel. If you were not, then gain the officer who blamed you as an Enemy, but you keep your Benefit roll from this term.",
			fx = { CH(OPT("You were responsible (one free Skills and Training roll)", { { "skillroll" } }), OPT("You were not (gain an Enemy, keep this term's Benefit roll)", { { "assoc", "enemy", 1 }, { "bkeep" } })) } },
		{ text = "You are tormented by or quarrel with an officer or fellow crewman. Gain that character as a Rival, as they force you out of the Navy.", fx = { { "assoc", "rival", 1 } } },
		{ text = "Injured. Roll on the Injury Table.", fx = { { "injury" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "You join a gambling circle on board. Gain Gambler 1 or Deception 1. If you wish, throw Gambler 8+. If you succeed, gain an extra Benefit roll from this career, if you fail, you lose one Benefit roll from this career.",
			fx = { PICK("Gambler 1", "Deception 1"), CH(OPT("Throw Gambler 8+", { CHK({ "Gambler" }, 8, { { "bextra", 1 } }, { { "blose", 1 } }) }), OPT("Don't gamble", {})) } },
		[4] = { text = "You are given a special assignment or duty on board ship. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[5] = { text = "You are given advanced training in a specialist field. Roll EDU 8+ to gain one level in any skill you already have.", fx = { CHK({ "EDU" }, 8, { { "gainany", nil, have = true } }, {}) } },
		[6] = { text = "Your vessel participates in a notable military engagement. Gain one of Electronics 1, Engineer 1, Gunner 1 or Pilot 1.", fx = { PICK("Electronics 1", "Engineer 1", "Gunner 1", "Pilot 1") } },
		[7] = LIFE,
		[8] = { text = "Your vessel participates in a diplomatic mission. Gain one of Recon 1, Diplomat 1, Steward 1 or a Contact.", fx = { PICK("Recon 1", "Diplomat 1", "Steward 1", "Contact") } },
		[9] = { text = "You foil an attempted crime on board, such as mutiny, sabotage, smuggling or conspiracy. Gain an Enemy, but also gain DM+2 to your next Advancement roll in the Navy.", fx = { { "assoc", "enemy", 1 }, { "adm", 2 } } },
		[10] = { text = "You have the opportunity to abuse your position for profit. If you do so, gain an extra Benefit roll from this term. Refuse, and you get DM+2 to your next Advancement roll.", fx = { CH(OPT("Abuse your position (extra Benefit roll)", { { "bextra", 1 } }), OPT("Refuse (DM+2 to your next Advancement roll)", { { "adm", 2 } })) } },
		[11] = { text = "Your commanding officer takes an interest in your career. Either gain Tactics (naval) 1 or DM+4 to your next Advancement roll thanks to their aid.", fx = { CH(OPT("Tactics (naval) 1", { G("Tactics (naval)", 1) }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "You display heroism in battle, saving the whole ship. You automatically pass your next promotion or commission roll.", fx = { { "autopass" } } },
	},
	benefits = {
		cash = { 1000, 5000, 5000, 10000, 20000, 50000, 50000 },
		other = { "Personal Vehicle or Ship Share", "INT +1", "EDU +1 or Two Ship Shares", "Weapon", "TAS Membership", "Ship's Boat or Two Ship Shares", "SOC +2" },
	},
};

CAREERS.noble = {
	name = "Noble",
	text = "Individuals of the upper class who perform little consistent function, but often have large amounts of ready money.",
	qual = { { "soc", 10 } }, socauto = 10,
	changeassign = "qual", medical = "civil", pension = true,
	assignments = {
		{ key = "administrator", name = "Administrator", text = "You serve in the planetary government or even ruled over a fiefdom or other domain.", surv = { "int", 4 }, adv = { "edu", 6 } },
		{ key = "diplomat", name = "Diplomat", text = "You are a diplomat or other state official.", surv = { "int", 5 }, adv = { "soc", 7 } },
		{ key = "dilettante", name = "Dilettante", text = "You are known for being known and have absolutely no useful function in society.", surv = { "soc", 3 }, adv = { "int", 8 } },
	},
	tables = {
		personal = { "STR +1", "DEX +1", "END +1", "Gambler", "Gun Combat", "Melee" },
		service = { "Admin", "Advocate", "Electronics", "Diplomat", "Investigate", "Persuade" },
		advanced = { min = 8, "Admin", "Advocate", "Language", "Leadership", "Diplomat", "Art" },
		administrator = { "Admin", "Advocate", "Broker", "Diplomat", "Leadership", "Persuade" },
		diplomat = { "Advocate", "Carouse", "Electronics", "Steward", "Diplomat", "Deception" },
		dilettante = { "Carouse", "Deception", "Flyer", "Streetwise", "Gambler", "Jack-of-all-Trades" },
	},
	ranks = {
		administrator = { [0] = { "Assistant" }, { "Clerk", "Admin 1" }, { "Supervisor" }, { "Manager", "Advocate 1" }, { "Chief" }, { "Director", "Leadership 1" }, { "Minister" } },
		diplomat = { [0] = { "Intern" }, { "3rd Secretary", "Admin 1" }, { "2nd Secretary" }, { "1st Secretary", "Advocate 1" }, { "Counsellor" }, { "Minister", "Diplomat 1" }, { "Ambassador" } },
		dilettante = { [0] = { "Wastrel" }, { "" }, { "Ingrate", "Carouse 1" }, { "" }, { "Black Sheep", "Persuade" }, { "" }, { "Scoundrel", "Jack-of-all-Trades 1" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "A family scandal forces you out of your position. Lose one SOC.", fx = { { "stat", "soc", -1 } } },
		{ text = "A disaster or war strikes. Roll Stealth 8+ or Deception 8+ to escape unhurt. If you fail, roll on the Injury Table.", fx = { CHK({ "Stealth", "Deception" }, 8, {}, { { "injury" } }) } },
		{ text = "Political manoeuvrings usurp your position. Increase Diplomat or Advocate by one level and gain a Rival.", fx = { PICK("Diplomat", "Advocate"), { "assoc", "rival", 1 } } },
		{ text = "An assassin attempts to end your life. Roll END 8+. If you fail, roll on the Injury Table.", fx = { CHK({ "END" }, 8, {}, { { "injury" } }) } },
		{ text = "Injured. Roll on the Injury Table.", fx = { { "injury" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "You are challenged to a duel for your honour and standing. If you refuse, reduce your SOC by 1. If you accept, roll Melee (blade) 8+. If you succeed, gain one SOC. If you fail, roll on the Injury Table and reduce your SOC by one. Either way, gain one level in Melee (blade), Leadership, Tactics (any) or Deception.",
			fx = { CH(OPT("Refuse (lose one SOC)", { { "stat", "soc", -1 } }), OPT("Accept the duel", { CHK({ "Melee (blade)" }, 8, { { "stat", "soc", 1 } }, { { "injury" }, { "stat", "soc", -1 } }) })), PICK("Melee (blade)", "Leadership", "Tactics", "Deception") } },
		[4] = { text = "Your time as a ruler or playboy gives you a wide range of experiences. Gain one of Animals (riding) 1, Art 1, Carouse 1, or Streetwise 1.", fx = { PICK("Animals (riding) 1", "Art 1", "Carouse 1", "Streetwise 1") } },
		[5] = { text = "You inherit a gift from a rich relative. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[6] = { text = "You become deeply involved in politics on your world of residence, becoming a player in the political intrigues of government. Gain one level in Advocate, Admin, Diplomacy or Persuade, but also gain a Rival.", fx = { PICK("Advocate", "Admin", "Diplomat", "Persuade"), { "assoc", "rival", 1 } } },
		[7] = LIFE,
		[8] = { text = "A conspiracy of nobles attempts to recruit you. If you refuse, gain the conspiracy as an Enemy. If you accept, roll Deception 8+ or Persuade 8+. If you fail, roll on the Mishap Table as the conspiracy collapses. If you succeed, Gain one level of Deception, Persuade, Tactics or Carouse.",
			fx = { CH(OPT("Refuse (gain an Enemy)", { { "assoc", "enemy", 1 } }), OPT("Accept", { CHK({ "Deception", "Persuade" }, 8, { PICK("Deception", "Persuade", "Tactics", "Carouse") }, { { "mishap" } }) })) } },
		[9] = { text = "Your reign is acclaimed by all as being fair and wise - or in the case of a dilettante, you sponge off your family's wealth a while longer. Gain either a jealous relative or an unhappy subject as an Enemy. Gain DM+2 to your next Advancement check.", fx = { { "assoc", "enemy", 1 }, { "adm", 2 } } },
		[10] = { text = "You manipulate and charm your way through high society. Gain one level of Carouse, Diplomat, Persuade or Steward, as well as a Rival and an Ally.", fx = { PICK("Carouse", "Diplomat", "Persuade", "Steward"), { "assoc", "rival", 1 }, { "assoc", "ally", 1 } } },
		[11] = { text = "You make an alliance with a powerful and charismatic noble, who becomes an Ally. Either gain one level of Leadership or DM+4 to your next Advancement roll thanks to their aid.", fx = { { "assoc", "ally", 1 }, CH(OPT("Leadership +1", { G("Leadership") }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "Your efforts do not go unnoticed by the Imperium. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 10000, 10000, 50000, 50000, 100000, 100000, 200000 },
		other = { "Ship Share", "Two Ship Shares", "Blade", "SOC +1", "TAS Membership", "Yacht", "SOC +1 and Yacht" },
	},
};

CAREERS.rogue = {
	name = "Rogue",
	text = "Criminal elements familiar with the rougher or more illegal methods of attaining goals.",
	qual = { { "dex", 6 } },
	changeassign = "qual", medical = "rough", pension = false,
	assignments = {
		{ key = "thief", name = "Thief", text = "You steal from the rich and give to... well, yourself, actually.", surv = { "int", 6 }, adv = { "dex", 6 } },
		{ key = "enforcer", name = "Enforcer", text = "You are a leg breaker, thug or assassin for a criminal group.", surv = { "end", 6 }, adv = { "str", 6 } },
		{ key = "pirate", name = "Pirate", text = "You are a space-going corsair.", surv = { "dex", 6 }, adv = { "int", 6 } },
	},
	tables = {
		personal = { "Carouse", "DEX +1", "END +1", "Gambler", "Melee", "Gun Combat" },
		service = { "Deception", "Recon", "Athletics", "Gun Combat", "Stealth", "Streetwise" },
		advanced = { min = 10, "Electronics", "Navigation", "Medic", "Investigate", "Broker", "Advocate" },
		thief = { "Stealth", "Electronics", "Recon", "Streetwise", "Deception", "Athletics" },
		enforcer = { "Gun Combat", "Melee", "Streetwise", "Persuade", "Athletics", "Drive" },
		pirate = { "Pilot", "Astrogation", "Gunner", "Engineer", "Vacc Suit", "Melee" },
	},
	ranks = {
		thief = { [0] = { "" }, { "", "Stealth 1" }, { "" }, { "", "Streetwise 1" }, { "" }, { "", "Recon 1" }, { "" } },
		enforcer = { [0] = { "" }, { "", "Persuade 1" }, { "" }, { "", "Gun Combat 1 or Melee 1" }, { "" }, { "", "Streetwise 1" }, { "" } },
		pirate = { [0] = { "Lackey" }, { "Henchman", "Pilot 1 or Gunner 1" }, { "Corporal" }, { "Sergeant", "Gun Combat 1 or Melee 1" }, { "Lieutenant" }, { "Leader", "Engineer 1 or Navigation 1" }, { "Captain" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "Arrested. You must take the Prisoner career in your next term.", fx = { { "prisoner" } } },
		{ text = "Betrayed by a friend. One of your Contacts or Allies betrays you, ending your career. That Contact or Ally becomes a Rival or Enemy. If you have no Contacts or Allies, then you are betrayed by someone you never saw coming and still gain a Rival or Enemy. In addition, roll 2D. If you roll 2, you must take the Prisoner career in your next term.", fx = { BETRAYED, { "prisoner2" } } },
		{ text = "A job goes wrong, forcing you to flee off-planet. Gain one of Deception 1, Pilot (small craft or spacecraft) 1, Athletics (dexterity) 1 or Gunner 1.", fx = { PICK("Deception 1", "Pilot (small craft) 1", "Pilot (spacecraft) 1", "Athletics (dexterity) 1", "Gunner 1") } },
		{ text = "A police detective or rival criminal forces you to flee and vows to hunt you down. Gain an Enemy.", fx = { { "assoc", "enemy", 1 } } },
		{ text = "Injured. Roll on the Injury Table.", fx = { { "injury" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "You are arrested and charged. You can choose to defend yourself, or hire a lawyer. If you defend yourself, roll Advocate 8+. If you succeed, the charges are dropped. If you fail, gain an Enemy and take the Prisoner career in your next term. If you hired a lawyer, gain the lawyer as a Contact and lose a Benefit roll.",
			fx = { CH(OPT("Defend yourself (Advocate 8+)", { CHK({ "Advocate" }, 8, {}, { { "assoc", "enemy", 1 }, { "prisoner" } }) }), OPT("Hire a lawyer (gain a Contact, lose a Benefit roll)", { { "assoc", "contact", 1, note = "your lawyer" }, { "blose", 1 } })) } },
		[4] = { text = "You are involved in the planning of an impressive heist. Gain Electronics 1 or Mechanic 1.", fx = { PICK("Electronics 1", "Mechanic 1") } },
		[5] = { text = "One of your crimes pays off. Gain DM+2 to any one Benefit roll, and gain your victim as an Enemy.", fx = { { "bdm", 2 }, { "assoc", "enemy", 1 } } },
		[6] = { text = "You have the opportunity to backstab a fellow rogue for personal gain. If you do so, gain DM+4 to your next Advancement check. If you refuse, gain them as an Ally.", fx = { CH(OPT("Backstab (DM+4 to your next Advancement roll)", { { "adm", 4 } }), OPT("Refuse (gain an Ally)", { { "assoc", "ally", 1 } })) } },
		[7] = LIFE,
		[8] = { text = "You spend months in the dangerous criminal underworld. Gain one of Streetwise 1, Stealth 1, Melee 1 or Gun Combat 1.", fx = { PICK("Streetwise 1", "Stealth 1", "Melee 1", "Gun Combat 1") } },
		[9] = { text = "You become involved in a feud with a rival criminal organisation. Roll Stealth or Gun Combat 8+. If you fail, roll on the Injury Table. If you succeed, gain an extra Benefit roll.", fx = { CHK({ "Stealth", "Gun Combat" }, 8, { { "bextra", 1 } }, { { "injury" } }) } },
		[10] = { text = "You are involved in a gambling ring. Gain Gambler 1. You may wager any number of Benefit rolls. Roll Gambler 8+, if you fail, lose all the wagered Benefit rolls. If you succeed, gain half as many Benefit rolls as you wagered (round up).", fx = { G("Gambler", 1), { "gamble", skills = { "Gambler" } } } },
		[11] = { text = "A crime lord considers you his protege. Either gain Tactics (military) 1 or DM+4 to your next Advancement roll thanks to their aid.", fx = { CH(OPT("Tactics (military) 1", { G("Tactics (military)", 1) }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "You commit a legendary crime. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 0, 0, 10000, 10000, 50000, 100000, 100000 },
		other = { "Ship Share", "Weapon", "INT +1", "1D Ship Shares", "Armour", "DEX +1", "2D Ship Shares" },
	},
};

CAREERS.scholar = {
	name = "Scholar",
	text = "Individuals trained in technological or research sciences who conduct scientific investigations into materials, situations and phenomena, or who practise medicine.",
	qual = { { "int", 6 } },
	changeassign = "qual", medical = "civil", pension = true,
	assignments = {
		{ key = "field", name = "Field Researcher", text = "You are an explorer or field researcher, equally at home in the laboratory or wilderness.", surv = { "end", 6 }, adv = { "int", 6 } },
		{ key = "scientist", name = "Scientist", text = "You are a researcher in some corporation or research institution, or a mad scientist in an orbiting laboratory.", surv = { "edu", 4 }, adv = { "int", 8 } },
		{ key = "physician", name = "Physician", text = "You are a doctor, healer or medical researcher.", surv = { "edu", 4 }, adv = { "edu", 8 } },
	},
	tables = {
		personal = { "INT +1", "EDU +1", "SOC +1", "DEX +1", "END +1", "Language" },
		service = { "Drive", "Electronics", "Diplomat", "Medic", "Investigate", "Science" },
		advanced = { min = 10, "Art", "Advocate", "Electronics", "Language", "Engineer", "Science" },
		field = { "Electronics", "Vacc Suit", "Navigation", "Survival", "Investigate", "Science" },
		scientist = { "Admin", "Engineer", "Science", "Science", "Electronics", "Science" },
		physician = { "Medic", "Electronics", "Investigate", "Medic", "Persuade", "Science" },
	},
	ranks = {
		field = { [0] = { "" }, { "", "Science 1" }, { "", "Electronics (computers) 1" }, { "", "Investigate 1" }, { "" }, { "", "Science 2" }, { "" } },
		scientist = { [0] = { "" }, { "", "Science 1" }, { "", "Electronics (computers) 1" }, { "", "Investigate 1" }, { "" }, { "", "Science 2" }, { "" } },
		physician = { [0] = { "" }, { "", "Medic 1" }, { "" }, { "", "Science 1" }, { "" }, { "", "Science 2" }, { "" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "A disaster leaves several injured, and others blame you, forcing you to leave your career. Roll on the Injury Table twice, taking the higher result, and gain a Rival.", fx = { { "injury", "higher" }, { "assoc", "rival", 1 } } },
		{ text = "The planetary government interferes with your research for political or religious reasons. If you continue with your work openly, increase Science by one level and gain an Enemy. If you continue with your work secretly, increase Science by one level and reduce your SOC by 2. This mishap does not cause you to leave this career.",
			fx = { G("Science"), CH(OPT("Continue openly (gain an Enemy)", { { "assoc", "enemy", 1 } }), OPT("Continue secretly (SOC -2)", { { "stat", "soc", -2 } })), { "stay" } } },
		{ text = "An expedition or voyage goes wrong, leaving you stranded in the wilderness. Gain Survival 1 or Athletics (dexterity or endurance) 1. By the time you find your way home, your job is gone.", fx = { PICK("Survival 1", "Athletics (dexterity) 1", "Athletics (endurance) 1") } },
		{ text = "Your work is sabotaged by unknown parties. You may salvage what you can and give up (leave the career but retain this term's Benefit roll) or start again from scratch (lose all Benefit rolls from this career but you do not have to leave).",
			fx = { CH(OPT("Give up (leave, keep this term's Benefit roll)", { { "bkeep" } }), OPT("Start again (stay, lose all Benefit rolls from this career)", { { "bloseall" }, { "stay" } })) } },
		{ text = "A rival researcher blackens your name or steals your research. Gain a Rival but you do not have to leave this career.", fx = { { "assoc", "rival", 1 }, { "stay" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "You are called upon to perform research that goes against your conscience. Accept, and you gain an extra Benefit roll, a level in each of any two Science skill specialties and D3 Enemies.",
			fx = { CH(OPT("Accept", { { "bextra", 1 }, G("Science"), G("Science"), { "assoc", "enemy", "D3" } }), OPT("Refuse", {})) } },
		[4] = { text = "You are assigned to work on a secret project for a patron or organisation. Gain one of Medic 1, Science 1, Engineer 1, Electronics 1 or Investigate 1.", fx = { PICK("Medic 1", "Science 1", "Engineer 1", "Electronics 1", "Investigate 1") } },
		[5] = { text = "You win a prestigious prize for your work, garnering both the praise and envy of your peers. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[6] = { text = "You are given advanced training in a specialist field. Roll EDU 8+ to gain any one skill of your choice at level 1.", fx = { CHK({ "EDU" }, 8, { { "gainany", 1 } }, {}) } },
		[7] = LIFE,
		[8] = { text = "You have the opportunity to cheat in some fashion, advancing your career and research by stealing another's work, using an alien device, taking a shortcut and so forth. If you refuse, you gain nothing. If you accept, roll Deception 8+ or Admin 8+. If you succeed, you gain DM+2 to any one Benefit roll and may increase any skill by one level, but also gain an Enemy. If you fail, gain an Enemy and lose one Benefit roll from this career.",
			fx = { CH(OPT("Cheat", { CHK({ "Deception", "Admin" }, 8, { { "bdm", 2 }, { "gainany" }, { "assoc", "enemy", 1 } }, { { "assoc", "enemy", 1 }, { "blose", 1 } }) }), OPT("Refuse", {})) } },
		[9] = { text = "You make a breakthrough in your field. Gain DM+2 to your next Advancement check.", fx = { { "adm", 2 } } },
		[10] = { text = "You become entangled in a bureaucratic or legal morass that distracts you from your work. Gain one of Admin 1, Advocate 1, Persuade 1 or Diplomat 1.", fx = { PICK("Admin 1", "Advocate 1", "Persuade 1", "Diplomat 1") } },
		[11] = { text = "You work for an eccentric but brilliant mentor, who becomes an Ally. Either increase Science by one level or DM+4 to your next Advancement roll thanks to their aid.", fx = { { "assoc", "ally", 1 }, CH(OPT("Science +1", { G("Science") }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "Your work leads to a considerable breakthrough. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 5000, 10000, 20000, 30000, 40000, 60000, 100000 },
		other = { "INT +1", "EDU +1", "Two Ship Shares", "SOC +1", "Scientific Equipment", "Lab Ship", "Lab Ship" },
	},
};

CAREERS.scout = {
	name = "Scout",
	text = "Members of the exploratory service. Scouts explore new areas, map and survey known or newly discovered areas, and maintain communication ships which carry information and messages between the worlds of the galaxy.",
	qual = { { "int", 5 } },
	changeassign = "qual", medical = "rough", pension = false,
	assignments = {
		{ key = "courier", name = "Courier", text = "You are responsible for shuttling messages and high value packages around the galaxy.", surv = { "end", 5 }, adv = { "edu", 9 } },
		{ key = "surveyor", name = "Surveyor", text = "You visit border worlds and assess their worth.", surv = { "end", 6 }, adv = { "int", 8 } },
		{ key = "explorer", name = "Explorer", text = "You go wherever the map is blank, exploring unknown worlds and uncharted space.", surv = { "end", 7 }, adv = { "edu", 7 } },
	},
	tables = {
		personal = { "STR +1", "DEX +1", "END +1", "INT +1", "EDU +1", "Jack-of-all-Trades" },
		service = { "Pilot (small craft) or Pilot (spacecraft)", "Survival", "Mechanic", "Astrogation", "Vacc Suit", "Gun Combat" },
		advanced = { min = 8, "Medic", "Navigation", "Seafarer", "Explosives", "Science", "Jack-of-all-Trades" },
		courier = { "Electronics", "Flyer", "Pilot (spacecraft)", "Engineer", "Athletics", "Astrogation" },
		surveyor = { "Electronics", "Persuade", "Pilot", "Navigation", "Diplomat", "Streetwise" },
		explorer = { "Electronics", "Pilot", "Engineer", "Science", "Stealth", "Recon" },
	},
	ranks = {
		default = { [0] = { "" }, { "Scout", "Vacc Suit 1" }, { "" }, { "Senior Scout", "Pilot 1" }, { "" }, { "" }, { "" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "Psychologically damaged by your time in the scouts. Reduce your INT or SOC by 1.", fx = { { "statpick", { "int", "soc" }, -1 } } },
		{ text = "Your ship is damaged, and you have to hitch-hike your way back across the stars to the nearest scout base. Gain 1D Contacts and D3 Enemies.", fx = { { "assoc", "contact", "1D" }, { "assoc", "enemy", "D3" } } },
		{ text = "You inadvertently cause a conflict between the Imperium and a minor world or race. Gain a Rival and Diplomat 1.", fx = { { "assoc", "rival", 1 }, G("Diplomat", 1) } },
		{ text = "You have no idea what happened to you - they found your ship drifting on the fringes of friendly space.", fx = {} },
		{ text = "Injured. Roll on the Injury Table.", fx = { { "injury" } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "Your ship is ambushed by enemy vessels. Either run, and roll Pilot 8+ to escape, or treat with them and roll Persuade 10+ to bargain with them. If you fail the check, then your ship is destroyed and you may not re-enlist in the Scouts at the end of this term. If you succeed, you survive and gain Electronics (sensors) 1. Either way, gain an Enemy.",
			fx = { CH(OPT("Run (Pilot 8+)", { CHK({ "Pilot" }, 8, { G("Electronics (sensors)", 1) }, { { "noreenlist" } }) }), OPT("Treat with them (Persuade 10+)", { CHK({ "Persuade" }, 10, { G("Electronics (sensors)", 1) }, { { "noreenlist" } }) })), { "assoc", "enemy", 1 } } },
		[4] = { text = "You survey an alien world. Gain one of Animals (riding or training) 1, Survival 1, Recon 1 or Science 1.", fx = { PICK("Animals (riding) 1", "Animals (training) 1", "Survival 1", "Recon 1", "Science 1") } },
		[5] = { text = "You perform an exemplary service for the scouts. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[6] = { text = "You spend several years jumping from world to world in your scout ship. Gain one of Astrogation 1, Electronics 1, Navigation 1, Pilot (small craft) 1 or Mechanic 1.", fx = { PICK("Astrogation 1", "Electronics 1", "Navigation 1", "Pilot (small craft) 1", "Mechanic 1") } },
		[7] = LIFE,
		[8] = { text = "When dealing with an alien race, you have an opportunity to gather extra intelligence about them. Roll either Electronics 8+ or Deception 8+. If you succeed, gain an Ally in the Imperium and DM+2 to your next Advancement roll. If you fail, roll on the Mishap Table, but you are not ejected from this career.",
			fx = { CHK({ "Electronics", "Deception" }, 8, { { "assoc", "ally", 1 }, { "adm", 2 } }, { { "mishap", noeject = true } }) } },
		[9] = { text = "Your scout ship is one of the first on the scene to rescue the survivors of a disaster. Roll either Medic 8+ or Engineer 8+. If you succeed, gain a Contact and DM+2 to your next Advancement check. If you fail, gain an Enemy.",
			fx = { CHK({ "Medic", "Engineer" }, 8, { { "assoc", "contact", 1 }, { "adm", 2 } }, { { "assoc", "enemy", 1 } }) } },
		[10] = { text = "You spend a great deal of time on the fringes of Charted Space. Roll Survival 8+ or Pilot 8+. If you succeed, gain a Contact in an alien race and one level in any skill of your choice. If you fail, roll on the Mishap Table but you are not ejected from this career.",
			fx = { CHK({ "Survival", "Pilot" }, 8, { { "assoc", "contact", 1, note = "in an alien race" }, { "gainany" } }, { { "mishap", noeject = true } }) } },
		[11] = { text = "You serve as the courier for an important message from the Imperium. Either gain one level of Diplomat or DM+4 to your next Advancement roll.", fx = { CH(OPT("Diplomat +1", { G("Diplomat") }), OPT("DM+4 to your next Advancement roll", { { "adm", 4 } })) } },
		[12] = { text = "You discover a world, item or information of worth to the Imperium. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 20000, 20000, 30000, 30000, 50000, 50000, 50000 },
		other = { "Ship Share", "INT +1", "EDU +1", "Weapon", "Weapon", "Scout Ship", "Scout Ship" },
	},
};

CAREERS.psion = {
	name = "Psion",
	text = "A career for Travellers who choose to focus on their psionic potential instead of more conventional lifestyles.",
	qual = { { "psi", 6 } }, needpsi = true,
	changeassign = "qual", medical = "civil", pension = true,
	assignments = {
		{ key = "wild", name = "Wild Talent", text = "You developed your powers without formal training.", surv = { "soc", 6 }, adv = { "int", 8 } },
		{ key = "adept", name = "Adept", text = "You are a scholar of the psionic disciplines.", surv = { "edu", 4 }, adv = { "edu", 8 } },
		{ key = "warrior", name = "Psi-Warrior", text = "You combine combat training with psionic warfare.", surv = { "end", 6 }, adv = { "end", 6 } },
	},
	tables = {
		personal = { "EDU +1", "INT +1", "STR +1", "DEX +1", "END +1", "PSI +1" },
		service = { "Telepathy", "Clairvoyance", "Telekinesis", "Awareness", "Teleportation", "Any Talent" },
		advanced = { min = 8, "Language", "Art", "Electronics", "Medic", "Science", "Mechanic" },
		wild = { "Telepathy", "Telekinesis", "Deception", "Stealth", "Streetwise", "Melee or Gun Combat" },
		adept = { "Telepathy", "Clairvoyance", "Awareness", "Medic", "Persuade", "Science" },
		warrior = { "Telepathy", "Awareness", "Teleportation", "Gun Combat", "Vacc Suit", "Recon" },
	},
	ranks = {
		wild = { [0] = { "" }, { "Survivor", "Survival 1 or Streetwise 1" }, { "" }, { "Witch", "Deception 1" }, { "" }, { "" }, { "" } },
		adept = { [0] = { "" }, { "Initiate", "Science (psionicology) 1" }, { "" }, { "Acolyte", "Any Talent 1" }, { "" }, { "" }, { "Master", "Any Talent 1" } },
		warrior = { [0] = { "Marine" }, { "", "Gun Combat 1" }, { "Captain", "Leadership 1" }, { "" }, { "" }, { "Force Commander", "Tactics 1" }, { "" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "You telepathically contact something dangerous. Lose one PSI. You also suffer from persistent and terrifying nightmares.", fx = { { "stat", "psi", -1 }, NOTE("Persistent, terrifying nightmares") } },
		{ text = "An anti-psi cult or gang attempts to expose or attack you. Roll 1D - on a 1-2, you are injured.", fx = { { "t1d", { { 1, 2, { { "injury" } } }, { 3, 6, {} } } } } },
		{ text = "You are asked to use your psionic powers in an unethical fashion. Accept, and you may continue in this career, but you gain an Enemy. Refuse, and you must leave the career.", fx = { CH(OPT("Accept (stay; gain an Enemy)", { { "stay" }, { "assoc", "enemy", 1 } }), OPT("Refuse (leave)", {})) } },
		{ text = "You are experimented on by a corporation, government, or other organisation. You escape, but are forced to leave this career.", fx = {} },
		{ text = "Your gift causes a former ally to turn on you and betray you. One Ally or Contact becomes an Enemy.", fx = { { "convert", to = "enemy", fallback = true } } },
	},
	events = {
		[2] = DISASTER,
		[3] = { text = "Your psionic abilities make you uncomfortable to be around. One Contact or Ally becomes a Rival.", fx = { { "convert", to = "rival" } } },
		[4] = { text = "Choose one of these skills, reflecting your time spent mastering mind and body. Gain one of Athletics (any) 1, Stealth 1, Survival 1 or Art (any) 1.", fx = { PICK("Athletics 1", "Stealth 1", "Survival 1", "Art 1") } },
		[5] = { text = "You have a chance to use your powers unethically to better your standing. If you accept, roll PSI 8+. If you succeed, gain an extra Benefit roll or +1 SOC. If you fail, lose one SOC.",
			fx = { CH(OPT("Accept", { CHK({ "PSI" }, 8, { CH(OPT("An extra Benefit roll", { { "bextra", 1 } }), OPT("SOC +1", { { "stat", "soc", 1 } })) }, { { "stat", "soc", -1 } }) }), OPT("Refuse", {})) } },
		[6] = { text = "You make an unexpected connection outside your normal circles. Gain a Contact.", fx = { { "assoc", "contact", 1 } } },
		[7] = LIFE,
		[8] = { text = "You achieve a new level of psionic strength. Increase your PSI by +1.", fx = { { "stat", "psi", 1 } } },
		[9] = { text = "You are given advanced training in a specialist field. Roll EDU 8+ to gain any one skill except Jack-of-all-Trades.", fx = { CHK({ "EDU" }, 8, { { "gainany", nil, nojoat = true } }, {}) } },
		[10] = { text = "You pick up potentially useful information using your psychic powers. Gain DM+1 to any one Benefit roll.", fx = { { "bdm", 1 } } },
		[11] = { text = "You gain a mentor. Gain an Ally and DM+4 to your next Advancement roll (in any career) thanks to his aid.", fx = { { "assoc", "ally", 1 }, { "adm", 4 } } },
		[12] = { text = "You achieve a new level of discipline in your powers. You are automatically promoted.", fx = { { "promote" } } },
	},
	benefits = {
		cash = { 1000, 2000, 4000, 4000, 8000, 8000, 16000 },
		other = { "Gun", "Two Ship Shares", "Contact", "TAS Membership", "Contact", "Combat Implant", "10 Ship Shares" },
	},
};

CAREERS.prisoner = {
	name = "Prisoner",
	text = "Every society has its bad apples and even in the far future punishments usually take place within faceless institutions where criminals can be conveniently forgotten. You cannot enter this career voluntarily, and you leave it only when your Advancement roll beats your Parole Threshold.",
	qual = {}, forced = true, prison = true,
	changeassign = "free", medical = "rough", pension = false,
	assignments = {
		{ key = "inmate", name = "Inmate", text = "You just try to get through your time in prison without getting into trouble.", surv = { "end", 7 }, adv = { "str", 7 } },
		{ key = "thug", name = "Thug", text = "You are part of a gang in prison, terrorising the other inmates.", surv = { "str", 8 }, adv = { "end", 6 } },
		{ key = "fixer", name = "Fixer", text = "You can arrange anything - for the right price.", surv = { "int", 9 }, adv = { "end", 5 } },
	},
	tables = {
		personal = { "STR +1", "Melee (unarmed)", "END +1", "Jack-of-all-Trades", "EDU +1", "Gambler" },
		service = { "Athletics", "Deception", "Profession", "Streetwise", "Melee (unarmed)", "Persuade" },
		inmate = { "Stealth", "Melee (unarmed)", "Streetwise", "Survival", "Athletics (strength)", "Mechanic" },
		thug = { "Persuade", "Melee (unarmed)", "Melee (unarmed)", "Melee (blade)", "Athletics (strength)", "Athletics (strength)" },
		fixer = { "Investigate", "Broker", "Deception", "Streetwise", "Stealth", "Admin" },
	},
	ranks = {
		default = { [0] = { "", "Melee (unarmed) 1" }, { "" }, { "", "Athletics 1" }, { "" }, { "", "Advocate 1" }, { "" }, { "", "END +1" } },
	},
	mishaps = {
		{ text = SEVERE_TEXT, fx = { SEVERE } },
		{ text = "You are accused of assaulting a prison guard. Parole Threshold +2.", fx = { { "parole", 2 } } },
		{ text = "A prison gang persecutes you. You may choose to fight back if you wish, but if you do not, you lose all Benefit rolls from your prison career. If you fight back, roll Melee (unarmed) 8+. Fail, and you must roll twice on the Injury Table and take the lower result. Succeed, and you gain an Enemy and raise Parole Threshold by +1.",
			fx = { CH(OPT("Don't fight back (lose all Benefit rolls from prison)", { { "bloseall" } }), OPT("Fight back (Melee (unarmed) 8+)", { CHK({ "Melee (unarmed)" }, 8, { { "assoc", "enemy", 1 }, { "parole", 1 } }, { { "injury", "lower" } }) })) } },
		{ text = "A guard takes a dislike to you. Gain an Enemy and raise your Parole Threshold by +1.", fx = { { "assoc", "enemy", 1 }, { "parole", 1 } } },
		{ text = "Disgraced. Word of your criminal past reaches your homeworld. Lose 1 SOC.", fx = { { "stat", "soc", -1 } } },
		{ text = "Injured. Roll on the Injury table.", fx = { { "injury" } } },
	},
	events = {
		[2] = { text = "Disaster! Roll on the Mishap Table. However, you are not ejected from this career.", fx = { { "mishap", noeject = true } } },
		[3] = { text = "You have the opportunity to escape the prison. If you take this opportunity, roll either Stealth 10+ or Deception 10+. Succeed, and you leave this career. Fail, and raise your Parole Threshold by +2.",
			fx = { CH(OPT("Try to escape (Stealth or Deception 10+)", { CHK({ "Stealth", "Deception" }, 10, { { "escape" } }, { { "parole", 2 } }) }), OPT("Stay put", {})) } },
		[4] = { text = "You are assigned to difficult or backbreaking labour. Roll END 8+. If you fail, increase your Parole Threshold by +1. Succeed, and you may reduce your Parole Threshold by 1 and gain any one of the following skills: Athletics (any) 1, Mechanic 1, or Melee (unarmed) 1.",
			fx = { CHK({ "END" }, 8, { { "parole", -1 }, PICK("Athletics 1", "Mechanic 1", "Melee (unarmed) 1") }, { { "parole", 1 } }) } },
		[5] = { text = "You have the opportunity to join a gang. Make a Persuade or Melee check to do so. If you fail, you gain an Enemy. Succeed, and you must raise your Parole Threshold by +1, but you gain DM+1 to all Survival rolls in this career and may gain any one of the following skills: Deception 1, Persuade 1, Melee (unarmed) 1 or Stealth 1.",
			fx = { CH(OPT("Join the gang (Persuade or Melee 8+)", { CHK({ "Persuade", "Melee" }, 8, { { "parole", 1 }, { "gangdm" }, PICK("Deception 1", "Persuade 1", "Melee (unarmed) 1", "Stealth 1") }, { { "assoc", "enemy", 1 } }) }), OPT("Stay out of it", {})) } },
		[6] = { text = "Vocational Training. Roll EDU 8+ to gain any one skill except Jack-of-all-Trades.", fx = { CHK({ "EDU" }, 8, { { "gainany", nil, nojoat = true } }, {}) } },
		[7] = { text = "Prison Event.", fx = { { "t1d", {
			{ 1, 1, { NOTE("Riot"), { "t1d", { { 1, 2, { { "injury" } } }, { 3, 4, {} }, { 5, 6, { NOTE("Looted something useful in the riot") } } } } } },
			{ 2, 2, { NOTE("New Contact: another inmate"), { "assoc", "contact", 1 } } },
			{ 3, 3, { NOTE("New Rival among the inmates or guards"), { "assoc", "rival", 1 } } },
			{ 4, 4, { NOTE("Transferred to a different prison"), { "parolereroll" } } },
			{ 5, 5, { NOTE("Good behaviour"), { "parole", -2 } } },
			{ 6, 6, { NOTE("Attacked by another prisoner"), CHK({ "Melee (unarmed)" }, 8, {}, { { "injury" } }) } },
		} } }, prisonevent = { "1 - Riot. A riot engulfs the prison. Roll 1D. On a 1-2, you are injured - roll on the Injury table. On a 5-6, you are able to loot something useful.",
			"2 - New Contact. You make friends with another inmate.", "3 - New Rival. You gain a new rival among the inmates or guards.",
			"4 - Transferred. You are moved to a different prison. Re-roll your Parole Threshold.", "5 - Good Behaviour. Reduce your Parole Threshold by -2.",
			"6 - You are attacked by another prisoner. Roll Melee (unarmed) 8+. If you fail, roll on the Injury table." } },
		[8] = { text = "Parole hearing. Reduce your Parole Threshold by -1.", fx = { { "parole", -1 } } },
		[9] = { text = "You have the opportunity to hire a new lawyer. He costs Cr1000 x his Advocate skill squared. Roll 2D + your lawyer's Advocate skill.", fx = { { "lawyer" } } },
		[10] = { text = "Special Duty. You are given a special responsibility in the prison. Gain one of Admin, Advocate, Electronics (computers) or Steward.", fx = { PICK("Admin", "Advocate", "Electronics (computers)", "Steward") } },
		[11] = { text = "The warden takes an interest in your case. Reduce your Parole Threshold by -2.", fx = { { "parole", -2 } } },
		[12] = { text = "Heroism. You have the opportunity to save a guard or prison officer. If you take the risk, roll 2D. On a 7 or less, roll on the Injury table. On 8+, gain an Ally and reduce your Parole Threshold by -2.",
			fx = { CH(OPT("Take the risk (2D: 8+ succeeds)", { CHK({ "2D" }, 8, { { "assoc", "ally", 1 }, { "parole", -2 } }, { { "injury" } }) }), OPT("Stay back", {})) } },
	},
	benefits = {
		cash = { 0, 0, 100, 200, 500, 1000, 2500 },
		other = { "Contact", "Blade", "Deception or Persuade or Stealth", "Ally", "Melee or Recon or Streetwise", "STR +1 or END +1", "Deception and Persuade and Stealth" },
	},
};
