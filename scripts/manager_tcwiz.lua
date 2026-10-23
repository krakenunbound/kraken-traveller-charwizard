-- Traveller (Mongoose 2E) character creation wizard. Package TCWizard.
--
-- The build lives in a Lua table (S) on the machine running the wizard; the
-- character is only written when the player presses Create Character.
-- Careers are played one term at a time by a small engine: each step shows
-- one "task" (a title, the rules text and buttons); pressing a button either
-- rolls dice (in chat, through ActionsManager) or runs the choice, and the
-- engine continues. Event, mishap, rank and benefit effects are data
-- (TCData, data_tcwiz.lua) run by runFx. See dev/DESIGN.md.

TABS = { "characteristics", "species", "background", "careers", "benefits", "skills", "finish" };
local ROLLTYPE = "tcwiz";
local S = {};
local _w = nil;
local _gen = 0;
local _rolls = {};
local _nextRoll = 0;
local _creationPending = false;

function onInit()
	ActionsManager.registerResultHandler(ROLLTYPE, onRoll);
	-- Our rolls carry their own modifiers: keep the desktop modifier box out of them.
	if GameManager and GameManager.addAction then
		GameManager.addAction(ROLLTYPE, { bUseModStack = false });
	end
	OptionsManager.registerOptionData({ sKey = "TCWIZ_REROLL", sGroupRes = "option_header_tcwiz", tCustom = { default = "off" } });
	OptionsManager.registerOptionData({ sKey = "TCWIZ_RULES", sGroupRes = "option_header_tcwiz",
		tCustom = { labelsres = "option_val_tcwiz_2022", values = "2022", baselabelres = "option_val_tcwiz_2016", baseval = "2016", default = "2016" } });
	registerWithBridge();
	reset();
end

-- Lets the Kraken Agent Bridge (a developer tool) drive and test the wizard.
function registerWithBridge()
	local tBridge = AgentBridge or ClaudeBridge;
	if tBridge and tBridge.registerPackage then
		tBridge.registerPackage("TCWizard", TCWizard);
		tBridge.registerPackage("TCData", TCData);
	end
end

--
-- State
--

function reset()
	_gen = _gen + 1;
	_rolls = {};
	S = {
		rolls = {}, base = {}, delta = {}, species = nil, psi = nil,
		bg = {}, homeworld = "",
		skills = {}, talents = {}, talentTries = 0,
		assoc = { contact = {}, ally = {}, rival = {}, enemy = {} },
		terms = {}, visits = {}, cur = nil, term = nil,
		log = {}, notes = {},
		task = nil, waiting = nil, started = false, done = false,
		draftUsed = false, cashRolls = 0,
		mods = { qdm = 0, adm = 0, sdm = 0 }, autopass = false, autoqual = {},
		forced = nil, lastLeft = nil, psiOffer = false,
		anag = { on = false, terms = 0 }, crisis = false,
		education = nil, rankBonusGiven = {},
		benefits = {}, cash = 0, shares = 0, tas = false, pension = 0, debts = {},
		injuries = {},
		connections = { {}, {} }, package = "", packagePicks = {},
		name = "", gender = "", appearance = "", why = "",
	};
end

function getState()
	return S;
end

-- Education and anagathics values of the chosen printing (TCData.RULES).
function R()
	return TCData.RULES[OptionsManager.getOption("TCWIZ_RULES")] or TCData.RULES["2016"];
end

function canReroll()
	return Session.IsHost or OptionsManager.isOption("TCWIZ_REROLL", "on");
end

--
-- Window and tabs
--

-- The unfinished build is kept when the window closes (until Create
-- Character, Start over, or a reload of FGU).
function registerWindow(w)
	registerWithBridge();
	_w = w;
	if not isInProgress() then
		reset();
	end
	showTab(S.tab or "characteristics");
end

function isInProgress()
	return #S.rolls > 0 or S.species ~= nil or next(S.bg) ~= nil;
end

function startOver()
	reset();
	showTab("characteristics");
end

function unregisterWindow(w)
	if _w == w then
		_w = nil;
	end
end

function getWindow()
	return _w;
end

function showTab(sTab)
	if not _w then return; end
	for _, v in ipairs(TABS) do
		local c = _w["sub_" .. v];
		if c then c.setVisible(v == sTab); end
	end
	S.tab = sTab;
	if sTab == "careers" and not S.started and isReadyForCareers() then
		S.started = true;
		applyBackground();
		beginTerm();
		return;
	end
	refresh();
end

function refresh()
	if not _w then return; end
	local sTab = S.tab or "characteristics";
	local c = _w["sub_" .. sTab];
	if c and c.subwindow and c.subwindow.update then
		c.subwindow.update();
	end
	updateTabs();
end

function updateTabs()
	local wTabs = _w and _w.sub_tabs and _w.sub_tabs.subwindow;
	if not wTabs then return; end
	for _, v in ipairs(TABS) do
		local c = wTabs["tab_" .. v];
		if c then
			c.setFrame(v == S.tab and "buttondown" or "buttonup", 5, 5, 5, 5);
			c.setText(Interface.getString("tcwiz_tab_" .. v));
			local sIcon = (#getTabAlerts(v) > 0) and "tcwiz_alert" or "button_dialog_ok_down";
			local cBadge = c.findWidget("tcwiz_done");
			if cBadge then
				cBadge.setBitmap(sIcon);
			else
				c.addBitmapWidget({ name = "tcwiz_done", icon = sIcon, position = "bottomright", x = -6, y = -6, w = 16, h = 16 });
			end
		end
	end
end

-- What each step still needs (tab badges and the Finish page's warnings).
function getTabAlerts(sTab)
	local t = {};
	if sTab == "characteristics" then
		if #S.rolls < 6 then table.insert(t, "Roll the six characteristics"); end
	elseif sTab == "species" then
		if not S.species then table.insert(t, "Choose a species"); end
	elseif sTab == "background" then
		local nChosen, nAllowed = getBackgroundCounts();
		if #S.rolls == 6 and nChosen < nAllowed then
			table.insert(t, string.format("Choose background skills (%d of %d)", nChosen, nAllowed));
		end
	elseif sTab == "careers" then
		if not S.done then table.insert(t, "Play your career terms and muster out"); end
	elseif sTab == "benefits" then
		for _, b in ipairs(S.benefits) do
			if b.kind == "item" and not b.item and not b.skilltaken and not b.declined then
				table.insert(t, "Choose your " .. b.name:lower());
			end
		end
		for _, inj in ipairs(S.injuries) do
			if not inj.settled then table.insert(t, "Settle medical care for an injury"); break; end
		end
	elseif sTab == "skills" then
		if S.done then
			for _, s in ipairs(getSkillWarnings()) do table.insert(t, s); end
		end
	elseif sTab == "finish" then
		if StringManager.trim(S.name or "") == "" then table.insert(t, "Enter a name"); end
	end
	return t;
end

function getAllWarnings()
	local t = {};
	for _, v in ipairs(TABS) do
		for _, s in ipairs(getTabAlerts(v)) do table.insert(t, s); end
	end
	return t;
end

-- Instructions sections: open or closed on every page together.
local _bInstructions = true;
function getInstructionsShown()
	return _bInstructions;
end
function setInstructionsShown(bShow)
	_bInstructions = bShow and true or false;
	if not _w then return; end
	for _, v in ipairs(TABS) do
		local c = _w["sub_" .. v];
		local wPage = c and c.subwindow;
		local wInstr = wPage and wPage.sub_instructions and wPage.sub_instructions.subwindow;
		if wInstr and wInstr.update then wInstr.update(); end
	end
end

-- Faded art behind a page.
function applyWallpaper(cControl, sIcon)
	if not cControl or not cControl.addBitmapWidget then return; end
	local cOld = cControl.findWidget and cControl.findWidget("tcwiz_wallpaper");
	if cOld then cOld.destroy(); end
	local nW, nH = 900, 600;
	if cControl.getSize then
		local w, h = cControl.getSize();
		if w and w > 0 then nW = w; end
		if h and h > 0 then nH = h; end
	end
	-- The art is 16:9; scale it to cover the whole page (the sides may be cut).
	local nDrawW = nW;
	local nDrawH = math.floor(nW * 9 / 16);
	if nDrawH < nH then
		nDrawH = nH;
		nDrawW = math.floor(nH * 16 / 9);
	end
	local cWidget = cControl.addBitmapWidget({ name = "tcwiz_wallpaper", icon = sIcon, position = "center", x = 0, y = 0, w = nDrawW, h = nDrawH });
	if cWidget and cWidget.setColor then
		cWidget.setColor("30FFFFFF");
	end
end

--
-- Log
--

function log(s)
	table.insert(S.log, s);
	if S.term then table.insert(S.term.lines, s); end
end

function note(s)
	table.insert(S.notes, s);
	log(s);
end

function getLogText()
	return table.concat(S.log, "\n");
end

--
-- Characteristics
--

function statShort(s) return TCData.STAT_SHORT[s] or s:upper(); end
function statName(s) return TCData.STAT_NAMES[s] or s; end

function getSpeciesNode()
	return S.species and DB.findNode(S.species) or nil;
end

function getSpeciesMods()
	local t = {};
	local node = getSpeciesNode();
	local sMods = node and DB.getValue(node, "characteristics", "") or "";
	for sPart in sMods:gmatch("([^,]+)") do
		local sStat, sSign, sNum = StringManager.trim(sPart):match("^(%a%a%a)%s*([+-])%s*(%d+)");
		if sStat then
			local n = tonumber(sNum) or 0;
			if sSign == "-" then n = -n; end
			t[sStat:lower()] = (t[sStat:lower()] or 0) + n;
		end
	end
	return t;
end

-- Score with species modifier (never below 1) and everything since.
function getStat(s)
	if s == "psi" then return S.psi or 0; end
	local nBase = S.base[s];
	if not nBase then return 0; end
	local n = nBase + (getSpeciesMods()[s] or 0);
	if n < 1 then n = 1; end
	return n + (S.delta[s] or 0);
end

function getStatDM(s)
	return TCData.getDM(getStat(s));
end

function getStatMax(s)
	return 15 + math.max(0, getSpeciesMods()[s] or 0);
end

function changeStat(s, n, bInjury)
	n = tonumber(n) or 0;
	if n == 0 then return; end
	if s == "psi" then
		local nOld = S.psi or 0;
		S.psi = math.max(0, nOld + n);
		log(string.format("PSI %+d (now %d).", n, S.psi));
		return;
	end
	local nCur = getStat(s);
	local nNew = nCur + n;
	if n > 0 and nNew > getStatMax(s) then
		local nExcess = nNew - getStatMax(s);
		nNew = getStatMax(s);
		if s == "soc" then
			S.shares = S.shares + nExcess;
			log(string.format("SOC is at its maximum: %d point(s) become Ship Shares.", nExcess));
		else
			log(string.format("%s is at its maximum (%d): %d point(s) lost.", statShort(s), getStatMax(s), nExcess));
		end
	end
	if nNew < 0 then nNew = 0; end
	S.delta[s] = (S.delta[s] or 0) + (nNew - nCur);
	log(string.format("%s %+d (now %d).", statShort(s), nNew - nCur, nNew));
	if bInjury and nNew < nCur then
		table.insert(S.injuries, { stat = s, points = nCur - nNew, visit = S.cur, rank = curVisit() and curVisit().rank or 0 });
	end
end

function rollCharacteristics()
	if #S.rolls == 6 and not canReroll() then return; end
	S.rolls = {};
	S.base = {};
	for i, s in ipairs(TCData.STATS) do
		roll({ dice = "2d6", desc = "Characteristic " .. i .. " (" .. statShort(s) .. ")" }, function(nTotal)
			S.rolls[i] = nTotal;
			S.base[s] = nTotal;
		end);
	end
end

function swapScores(sA, sB)
	if sA == sB or not S.base[sA] or not S.base[sB] or S.started then return; end
	S.base[sA], S.base[sB] = S.base[sB], S.base[sA];
	refresh();
end

function isReadyForCareers()
	return #S.rolls == 6 and S.species ~= nil;
end

--
-- Species
--

function getSpeciesList()
	local t, tSeen = {}, {};
	for _, sRoot in ipairs({ "reference.race", "race" }) do
		for _, node in ipairs(DB.getChildrenGlobal(sRoot)) do
			local sName = DB.getValue(node, "name", "");
			if sName ~= "" and not tSeen[sName:lower()] then
				tSeen[sName:lower()] = true;
				table.insert(t, node);
			end
		end
	end
	table.sort(t, function(a, b) return DB.getValue(a, "name", "") < DB.getValue(b, "name", ""); end);
	return t;
end

function selectSpecies(node)
	if S.started then return; end
	S.species = node and DB.getPath(node) or nil;
	refresh();
end

function getSourceName(node)
	local sModule = DB.getModule(node);
	if not sModule or sModule == "" then return "Campaign"; end
	local tInfo = Module.getModuleInfo(sModule);
	return (tInfo and tInfo.displayname ~= "" and tInfo.displayname) or sModule;
end

function openRecord(sClass, sPath)
	Interface.openWindow(sClass, sPath);
end

--
-- Skills
--

local function trim(s) return StringManager.trim(s or ""); end
function baseOf(s) return trim((s or ""):gsub("%s*%b()", "")); end
function specOf(s) return (s or ""):match("%((.-)%)"); end

local function canonical(s)
	s = trim(s);
	if s:lower() == "jack of all trades" or s:lower() == "jack-of-all-trades" then return "Jack-of-all-Trades"; end
	if s:lower() == "diplomacy" then return "Diplomat"; end
	return s;
end

local _tSpecCache = nil;
-- Specialties of each skill, from the loaded skill records and our list.
function getSpecialtyTable()
	if _tSpecCache then return _tSpecCache; end
	local t = {};
	for sBase, tList in pairs(TCData.SPECIALTIES) do
		t[sBase] = {};
		for _, s in ipairs(tList) do t[sBase][s:lower()] = s; end
	end
	for _, node in ipairs(DB.getChildrenGlobal("reference.skilldata")) do
		local sName = DB.getValue(node, "name", "");
		local sSpec = specOf(sName);
		if sSpec then
			local sBase = canonical(baseOf(sName));
			t[sBase] = t[sBase] or {};
			t[sBase][sSpec:lower()] = t[sBase][sSpec:lower()] or sSpec;
		end
	end
	_tSpecCache = t;
	return t;
end

function getSpecialties(sBase)
	local t = {};
	for _, s in pairs(getSpecialtyTable()[canonical(sBase)] or {}) do table.insert(t, s); end
	table.sort(t);
	return t;
end

function hasSpecialties(sBase)
	return next(getSpecialtyTable()[canonical(sBase)] or {}) ~= nil;
end

function isTalent(s)
	for _, v in ipairs(TCData.PSI_TALENTS) do
		if v:lower() == baseOf(s):lower() then return true; end
	end
	return false;
end

-- Level of a skill, or nil when untrained. A base name ("Electronics")
-- returns the best of the base and its specialties.
function getSkillLevel(sName)
	sName = canonical(sName);
	if isTalent(sName) then return S.talents[baseOf(sName)]; end
	if specOf(sName) then
		if S.skills[sName] then return S.skills[sName]; end
		return S.skills[baseOf(sName)];
	end
	local nBest = S.skills[sName];
	for k, n in pairs(S.skills) do
		if baseOf(k) == sName and (not nBest or n > nBest) then nBest = n; end
	end
	return nBest;
end

-- DM for a skill check during creation: the level, or -3 untrained
-- (Jack-of-all-Trades reduces the penalty).
function getSkillDM(sName)
	local n = getSkillLevel(sName);
	if n then return n; end
	return math.min(0, -3 + (S.skills["Jack-of-all-Trades"] or 0));
end

function getTotalSkillLevels()
	local n = 0;
	for _, v in pairs(S.skills) do if v > 0 then n = n + v; end end
	for _, v in pairs(S.talents) do if v > 0 then n = n + v; end end
	return n;
end

function getSkillLimit()
	return 3 * (getStat("int") + getStat("edu"));
end

-- Sets an exact skill name to a level, within the creation limits.
function setSkillLevel(sName, nLevel, sWhy)
	sName = canonical(sName);
	local nOld = S.skills[sName];
	if nOld and nLevel <= nOld then
		log(string.format("%s %d: no benefit (already %d).", sName, nLevel, nOld));
		return false;
	end
	if nLevel > 4 then
		log(string.format("%s cannot go above 4 during creation: the increase is lost.", sName));
		if nOld and nOld >= 4 then return false; end
		nLevel = 4;
	end
	local nAdd = math.max(0, nLevel) - math.max(0, nOld or 0);
	if nAdd > 0 and getTotalSkillLevels() + nAdd > getSkillLimit() then
		log(string.format("%s: total skill levels would pass 3 x (INT + EDU) = %d; the increase is lost.", sName, getSkillLimit()));
		return false;
	end
	S.skills[sName] = nLevel;
	local sBase = baseOf(sName);
	if specOf(sName) and not S.skills[sBase] and sBase ~= "Profession" then
		S.skills[sBase] = 0;
	end
	if S.term then
		S.term.skills = S.term.skills or {};
		S.term.skills[sName] = true;
	end
	log(string.format("%s %d%s.", sName, nLevel, sWhy and (" (" .. sWhy .. ")") or ""));
	return true;
end

-- Gains a skill: nLevel nil = +1 (or 1 if untrained), a number = at least that level.
-- A skill with specialties at level 1+ asks which specialty.
function gainSkill(sName, nLevel, ctx, fnNext)
	sName = canonical(sName);
	if isTalent(sName) then
		return gainTalent(baseOf(sName), nLevel, fnNext);
	end
	local sBase = baseOf(sName);
	if not specOf(sName) and hasSpecialties(sBase) and (nLevel == nil or nLevel >= 1) then
		local tOpts = {};
		local tSpecs = getSpecialties(sBase);
		table.sort(tSpecs, function(a, b)
			local na = S.skills[sBase .. " (" .. a .. ")"] or -1;
			local nb = S.skills[sBase .. " (" .. b .. ")"] or -1;
			if na ~= nb then return na > nb; end
			return a < b;
		end);
		for _, sSpec in ipairs(tSpecs) do
			local sFull = sBase .. " (" .. sSpec .. ")";
			local nCur = S.skills[sFull];
			local nNew = nLevel or ((nCur or 0) + 1);
			if nCur and nLevel and nCur >= nLevel then nNew = nCur; end
			table.insert(tOpts, { label = string.format("%s %d", sSpec, nNew) .. (nCur and string.format("  (now %d)", nCur) or ""),
				fn = function()
					if ctx then ctx.lastPicked = sFull; end
					applySkill(sFull, nLevel);
					fnNext();
				end });
		end
		return setTask({ title = "Choose a specialty: " .. sBase, grid = true,
			text = string.format("%s has specialties. At level 1 or more you take a specialty; a later level may raise the same one or start another.", sBase),
			options = tOpts });
	end
	if ctx then ctx.lastPicked = sName; end
	applySkill(sName, nLevel);
	fnNext();
end

function applySkill(sName, nLevel)
	local nCur = S.skills[sName];
	if nCur == nil and specOf(sName) and S.skills[baseOf(sName)] and baseOf(sName) ~= "Profession" then
		nCur = 0;
	end
	if nLevel == nil then
		setSkillLevel(sName, nCur and (nCur + 1) or 1);
	else
		if nCur and nCur >= nLevel then
			log(string.format("%s %d: no benefit (already %d).", sName, nLevel, nCur));
			return;
		end
		setSkillLevel(sName, nLevel);
	end
end

-- Psionic talents: a new talent must be learned (PSI check, Institute Testing).
function gainTalent(sTalent, nLevel, fnNext)
	if (S.psi or 0) <= 0 then
		log(sTalent .. ": you have no psionic strength; the talent is lost.");
		return fnNext();
	end
	local nCur = S.talents[sTalent];
	if nCur then
		local nNew = nLevel or (nCur + 1);
		if nNew > nCur then
			S.talents[sTalent] = math.min(4, nNew);
			log(string.format("%s %d.", sTalent, S.talents[sTalent]));
		end
		return fnNext();
	end
	local bFirst = (S.talentTries == 0);
	if bFirst and sTalent == "Telepathy" then
		S.talentTries = 1;
		S.talents[sTalent] = nLevel or 0;
		log("Telepathy learned (the first talent tried is always gained when it is Telepathy).");
		return fnNext();
	end
	local nDM = TCData.getDM(S.psi) + (TCData.PSI_LEARN_DM[sTalent] or 0) - S.talentTries;
	setTask({ title = "Learn " .. sTalent, text = string.format("You have not learned %s. Roll PSI 8+ to learn it (PSI DM %+d, learning DM %+d, %d earlier attempt(s)).", sTalent, TCData.getDM(S.psi), TCData.PSI_LEARN_DM[sTalent] or 0, S.talentTries),
		options = { { label = string.format("Roll to learn %s (8+, DM %+d)", sTalent, nDM), roll = { dice = "2d6", mod = nDM, target = 8, desc = "Learn " .. sTalent },
			fn = function(nTotal)
				S.talentTries = S.talentTries + 1;
				if nTotal >= 8 then
					S.talents[sTalent] = (nLevel and nLevel >= 1) and nLevel or 0;
					log(string.format("%s learned (%d).", sTalent, S.talents[sTalent]));
				else
					log(sTalent .. " was not learned.");
				end
				fnNext();
			end } } });
end

--
-- Associates
--

-- The first sentence of an event, shortened (who an associate is).
function shortEvent(s)
	local sFirst = (s or ""):match("^(.-[%.!:])%s") or s or "";
	sFirst = sFirst:gsub("[%.!:]$", "");
	if #sFirst > 70 then sFirst = sFirst:sub(1, 67) .. "..."; end
	return sFirst;
end

function addAssoc(sKind, n, sNote)
	local v = curVisit();
	local sWhere = v and TCData.CAREERS[v.key].name or (S.term and S.term.kind == "education" and "school") or "youth";
	local sEvent = S.eventname and (": " .. S.eventname) or "";
	for i = 1, n do
		local sEntry = string.format("met in %s, term %d%s", sWhere, S.term and S.term.n or 0, sNote and (", " .. sNote) or sEvent);
		table.insert(S.assoc[sKind], sEntry);
	end
	log(string.format("Gain %d %s%s.", n, n == 1 and sKind or ASSOC_PLURAL[sKind], sNote and (" " .. sNote) or ""));
end

ASSOC_PLURAL = { contact = "contacts", ally = "allies", rival = "rivals", enemy = "enemies" };

function getAssocText()
	local t = {};
	for _, k in ipairs({ "contact", "ally", "rival", "enemy" }) do
		if #S.assoc[k] > 0 then
			-- Several from one event read "3 x met in Agent, term 3: ...".
			local tOrder, tCount = {}, {};
			for _, sWho in ipairs(S.assoc[k]) do
				if not tCount[sWho] then table.insert(tOrder, sWho); end
				tCount[sWho] = (tCount[sWho] or 0) + 1;
			end
			local tParts = {};
			for _, sWho in ipairs(tOrder) do
				table.insert(tParts, (tCount[sWho] > 1 and (tCount[sWho] .. " x ") or "") .. sWho);
			end
			table.insert(t, string.format("%s (%d): %s", ASSOC_PLURAL[k]:sub(1, 1):upper() .. ASSOC_PLURAL[k]:sub(2), #S.assoc[k], table.concat(tParts, "; ")));
		end
	end
	return table.concat(t, "\n");
end

--
-- Rolls (shown in chat, handled here)
--

-- t = { dice = "2d6", mod = n, target = n, desc = "..." }; fn(nTotal, nNatural, tValues)
function roll(t, fn)
	_nextRoll = _nextRoll + 1;
	_rolls[_nextRoll] = fn;
	local aDice = DiceManager.convertStringToDice(t.dice or "2d6");
	local sDesc = "[Traveller creation] " .. (t.desc or "");
	if t.target then
		sDesc = sDesc .. string.format(" (%d+", t.target) .. ((t.mod or 0) ~= 0 and string.format(", DM %+d)", t.mod) or ")");
	elseif (t.mod or 0) ~= 0 then
		sDesc = sDesc .. string.format(" (DM %+d)", t.mod);
	end
	S.rollsPending = (S.rollsPending or 0) + 1;
	local rRoll = { sType = ROLLTYPE, sDesc = sDesc, aDice = aDice, nMod = t.mod or 0,
		nTCId = _nextRoll, nTCGen = _gen, nTarget = t.target, nMult = t.mult };
	ActionsManager.performAction(nil, nil, rRoll);
end

function onRoll(rSource, rTarget, rRoll)
	local nNatural = 0;
	local tValues = {};
	for _, v in ipairs(rRoll.aDice or {}) do
		local n = tonumber(v.result) or 0;
		nNatural = nNatural + n;
		table.insert(tValues, n);
	end
	local nTotal = nNatural + (tonumber(rRoll.nMod) or 0);
	local nTarget = tonumber(rRoll.nTarget);
	if nTarget then
		local bOK = nTotal >= nTarget;
		rRoll.sDesc = rRoll.sDesc .. (bOK and " [SUCCESS]" or " [FAILURE]");
	end
	if tonumber(rRoll.nMult) then
		rRoll.sDesc = rRoll.sDesc .. string.format(" [x%d = %d]", tonumber(rRoll.nMult), nTotal * tonumber(rRoll.nMult));
	end
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	local sName = trim(S.name);
	rMessage.sender = (sName ~= "" and sName) or (Session.IsHost and "GM" or (User.getUsername() or ""));
	rMessage.icon = nil;
	Comm.deliverChatMessage(rMessage);

	if tonumber(rRoll.nTCGen) ~= _gen then return; end
	S.rollsPending = math.max(0, (S.rollsPending or 1) - 1);
	local nId = tonumber(rRoll.nTCId);
	local fn = nId and _rolls[nId];
	if nId then _rolls[nId] = nil; end
	if S.waiting and S.waiting.id == nId then S.waiting = nil; end
	if fn then fn(nTotal, nNatural, tValues); end
	refresh();
end

--
-- Tasks: one step on the Careers page
--

-- t = { title, text, options = { { label, tip, fn, roll = { dice, mod, target, desc }, disabled } }, grid }
function setTask(t)
	S.task = t;
	refresh();
end

function getTask()
	return S.task;
end

-- Developer test hook (host only, through the bridge): runs one effect op
-- ("psitest", "prisoner", "draft", "life"...) at the current step, then
-- returns to that step. Lets a tester reach paths the dice rarely give.
function devRun(sOp, vArg)
	if not Session.IsHost then return; end
	if sOp == "anagathics" then
		S.anag.on = true;
		log("Test: you find a supply of anagathics.");
		return refresh();
	end
	local tSaved = S.task;
	S.task = nil;
	runFx({ { sOp, vArg } }, { title = "Test: " .. sOp }, function()
		S.task = tSaved;
		refresh();
	end);
end

-- The current step as plain data (for the bridge and testing).
function getTaskSummary()
	local t = S.task;
	if not t then
		return { title = (S.waiting or (S.rollsPending or 0) > 0) and "(waiting for a roll)" or (S.done and "(careers done)" or "(none)"), options = {} };
	end
	local tLabels = {};
	for i, o in ipairs(t.options or {}) do
		tLabels[i] = (o.disabled and "(disabled) " or "") .. (o.label or "");
	end
	return { title = t.title or "", text = t.text or "", options = tLabels };
end

function chooseOption(i)
	local t = S.task;
	if not t or S.waiting then return; end
	local o = t.options and t.options[i];
	if not o or o.disabled then return; end
	S.task = nil;
	if o.roll then
		S.waiting = { id = _nextRoll + 1, task = t, option = i };
		roll(o.roll, function(nTotal, nNatural, tValues) o.fn(nTotal, nNatural, tValues); end);
	else
		o.fn();
	end
	refresh();
end

-- The dice never came back (window closed, roll cancelled): offer the roll again.
function retryRoll()
	local w = S.waiting;
	if not w then return; end
	S.waiting = nil;
	S.task = w.task;
	refresh();
end

local function rollOpt(sLabel, tRoll, fn, sTip)
	return { label = sLabel, roll = tRoll, fn = fn, tip = sTip };
end

-- Rolls a single 2D/1D step with one button.
local function rollStep(sTitle, sText, sLabel, tRoll, fn)
	setTask({ title = sTitle, text = sText, options = { rollOpt(sLabel, tRoll, fn) } });
end

local function fmtDM(n) return string.format("%+d", n or 0); end

--
-- Spec strings ("Gun Combat 1", "DEX +1", "Drive or Flyer", "Contact", benefits)
--

function parseSpec(sSpec)
	local s = trim(sSpec);
	if s == "" or s == "-" then return {}; end
	if s:find(" or ") then
		local t = {};
		for sPart in (s .. " or "):gmatch("(.-) or ") do table.insert(t, trim(sPart)); end
		return { { "pick", t } };
	end
	if s:find(" and ") then
		local t = {};
		for sPart in (s .. " and "):gmatch("(.-) and ") do
			for _, op in ipairs(parseSpec(sPart)) do table.insert(t, op); end
		end
		return t;
	end
	local sStat, sNum = s:match("^(%a%a%a) ([+-]%d+)$");
	if sStat and TCData.STAT_SHORT[sStat:lower()] then
		return { { "stat", sStat:lower(), tonumber(sNum) } };
	end
	local sLower = s:lower();
	if sLower == "contact" or sLower == "ally" or sLower == "rival" or sLower == "enemy" then
		return { { "assoc", sLower, 1 } };
	end
	local sCount = s:match("^(.-) [Ss]hip [Ss]hares?$");
	if s == "Ship Share" or sCount then
		local tWords = { two = 2, three = 3 };
		local sC = (sCount or "1"):lower();
		if sC == "1d" or sC == "2d" then return { { "shares", sC:upper() } }; end
		return { { "shares", tWords[sC] or tonumber(sC) or 1 } };
	end
	if TCData.BENEFITS[s] then
		return { { "benefit", s } };
	end
	if s:match("^Any Talent") then
		return { { "anytalent", tonumber(s:match("(%d)$")) } };
	end
	local sName, sLevel = s:match("^(.-)%s+(%d)$");
	if sName then
		return { { "gain", sName, tonumber(sLevel) } };
	end
	return { { "gain", s, nil } };
end

function describeSpec(sSpec)
	return trim(sSpec);
end

--
-- The effects engine
--

-- Runs a list of effect ops in order; fnDone when all are settled.
function runFx(tFx, ctx, fnDone)
	ctx = ctx or {};
	local i = 0;
	local function step()
		i = i + 1;
		if not tFx or i > #tFx then
			if fnDone then return fnDone(); end
			return;
		end
		runOp(tFx[i], ctx, step);
	end
	step();
end

local function rollCount(v, fn)
	if type(v) == "number" then return fn(v); end
	if v == "D3" then
		return roll({ dice = "1d6", desc = "D3" }, function(n) fn(math.ceil(n / 2)); end);
	elseif v == "1D" then
		return roll({ dice = "1d6", desc = "1D" }, function(n) fn(n); end);
	elseif v == "2D" then
		return roll({ dice = "2d6", desc = "2D" }, function(n) fn(n); end);
	end
	fn(1);
end

local function careerName(v) return v and TCData.CAREERS[v.key].name or ""; end

function runOp(op, ctx, fnNext)
	local sOp = op[1];
	local v = curVisit();
	if sOp == "gain" then
		return gainSkill(op[2], op[3], ctx, fnNext);
	elseif sOp == "pick" then
		local tOpts = {};
		for _, sSpec in ipairs(op[2]) do
			table.insert(tOpts, { label = describeSpec(sSpec), fn = function()
				ctx.lastPicked = trim(sSpec:gsub("%s+[%+%-]?%d$", ""));
				runFx(parseSpec(sSpec), ctx, fnNext);
			end });
		end
		return setTask({ title = ctx.title or "Choose one", text = ctx.text or "", options = tOpts });
	elseif sOp == "choice" then
		local tOpts = {};
		for _, o in ipairs(op[2]) do
			table.insert(tOpts, { label = o.label, fn = function() runFx(o.fx, ctx, fnNext); end });
		end
		return setTask({ title = ctx.title or "Your choice", text = ctx.text or "", options = tOpts });
	elseif sOp == "gainany" then
		local tOpts = {};
		local tList = {};
		if op.have then
			local tSeen = {};
			for k in pairs(S.skills) do
				local sB = baseOf(k);
				if not tSeen[sB] then tSeen[sB] = true; table.insert(tList, sB); end
			end
			for k in pairs(S.talents) do table.insert(tList, k); end
		else
			for _, s in ipairs(TCData.ALL_SKILLS) do table.insert(tList, s); end
		end
		table.sort(tList);
		for _, s in ipairs(tList) do
			if not (op.nojoat and s == "Jack-of-all-Trades") then
				local nCur = getSkillLevel(s);
				table.insert(tOpts, { label = s .. (nCur and string.format(" (%d)", nCur) or ""), fn = function() gainSkill(s, op[2], ctx, fnNext); end });
			end
		end
		if #tOpts == 0 then
			log("No skill to raise.");
			return fnNext();
		end
		local sWhat = op[2] and string.format("at level %d", op[2]) or "+1 level";
		return setTask({ title = op.have and "Raise a skill you have" or "Choose any skill", text = (ctx.text or "") .. "\n\nGain " .. sWhat .. ".", options = tOpts, grid = true });
	elseif sOp == "anytalent" then
		local tOpts = {};
		for _, s in ipairs(TCData.PSI_TALENTS) do
			table.insert(tOpts, { label = s .. (S.talents[s] and string.format(" (%d)", S.talents[s]) or ""), fn = function() gainTalent(s, op[2], fnNext); end });
		end
		return setTask({ title = "Choose a psionic talent", text = ctx.text or "", options = tOpts });
	elseif sOp == "stat" then
		changeStat(op[2], op[3], ctx.injury);
		return fnNext();
	elseif sOp == "statpick" then
		local function apply(n)
			local tOpts = {};
			for _, s in ipairs(op[2]) do
				table.insert(tOpts, { label = string.format("%s %d to %d (%+d)", statShort(s), getStat(s), math.max(0, getStat(s) + n), n), fn = function() changeStat(s, n, ctx.injury or n < 0); fnNext(); end });
			end
			setTask({ title = "Choose a characteristic", text = ctx.text or "", options = tOpts });
		end
		if op[3] == "-1D" then
			return roll({ dice = "1d6", desc = "Characteristic loss (1D)" }, function(n) apply(-n); end);
		end
		return apply(op[3]);
	elseif sOp == "socmin" then
		local nCur = getStat("soc");
		if nCur + 1 >= op[2] then changeStat("soc", 1); else changeStat("soc", op[2] - nCur); end
		return fnNext();
	elseif sOp == "assoc" then
		if op.ifnone and #S.assoc[op[2]] > 0 then
			log("You already have an " .. op[2] .. ".");
			return fnNext();
		end
		return rollCount(op[3], function(n) addAssoc(op[2], n, op.note); fnNext(); end);
	elseif sOp == "convert" then
		local tOpts = {};
		local tTo = op.to and { op.to } or { "rival", "enemy" };
		for _, sFrom in ipairs({ "contact", "ally" }) do
			for i, sWho in ipairs(S.assoc[sFrom]) do
				for _, sTo in ipairs(tTo) do
					table.insert(tOpts, { label = string.format("%s %s becomes a %s", sFrom:sub(1, 1):upper() .. sFrom:sub(2), sWho, sTo), fn = function()
						table.remove(S.assoc[sFrom], i);
						table.insert(S.assoc[sTo], sWho .. " (turned)");
						log(string.format("A %s turns %s.", sFrom, sTo));
						fnNext();
					end });
				end
			end
		end
		if #tOpts == 0 then
			if op.fallback or not op.to then
				for _, sTo in ipairs(tTo) do
					table.insert(tOpts, { label = "Gain a " .. sTo, fn = function() addAssoc(sTo, 1); fnNext(); end });
				end
			else
				log("No Contact or Ally to turn.");
				return fnNext();
			end
		end
		return setTask({ title = "Betrayal", text = ctx.text or "", options = tOpts });
	elseif sOp == "bdm" then
		if v then table.insert(v.bdm, op[2]); end
		log(string.format("DM+%d to one Benefit roll from this career.", op[2]));
		return fnNext();
	elseif sOp == "bextra" then
		if v then v.bextra = v.bextra + (op[2] or 1); end
		log("An extra Benefit roll.");
		return fnNext();
	elseif sOp == "blose" then
		if v then v.blost = v.blost + (op[2] or 1); end
		log("Lose a Benefit roll.");
		return fnNext();
	elseif sOp == "bloseall" then
		if v then v.bloseall = true; end
		log("Lose all Benefit rolls from this career.");
		return fnNext();
	elseif sOp == "bkeep" then
		if v then v.keepbenefit = true; end
		log("You keep this term's Benefit roll.");
		return fnNext();
	elseif sOp == "adm" then
		S.mods.adm = S.mods.adm + op[2];
		log(string.format("DM%+d to your next Advancement roll.", op[2]));
		return fnNext();
	elseif sOp == "qdm" then
		S.mods.qdm = S.mods.qdm + op[2];
		log(string.format("DM%+d to your next Qualification roll.", op[2]));
		return fnNext();
	elseif sOp == "sdm" then
		S.mods.sdm = S.mods.sdm + op[2];
		log(string.format("DM%+d to your next Survival roll.", op[2]));
		return fnNext();
	elseif sOp == "promote" then
		if v then v.autoPromote = true; end
		log("You are automatically promoted.");
		return fnNext();
	elseif sOp == "promoteorcomm" then
		local c = v and TCData.CAREERS[v.key];
		if c and c.commission and not v.officer then
			return setTask({ title = "Heroism", text = ctx.text or "", options = {
				{ label = "Take a commission (become an officer, rank 1)", fn = function() v.autoCommission = true; log("You will be commissioned automatically."); fnNext(); end },
				{ label = "Take a promotion", fn = function() v.autoPromote = true; log("You are automatically promoted."); fnNext(); end } } });
		end
		if v then v.autoPromote = true; end
		log("You are automatically promoted.");
		return fnNext();
	elseif sOp == "autopass" then
		S.autopass = true;
		log("You automatically pass your next promotion or commission roll.");
		return fnNext();
	elseif sOp == "injury" then
		return doInjury(op[2], ctx, fnNext);
	elseif sOp == "nearlykilled" then
		return roll({ dice = "1d6", desc = "Nearly killed (1D)" }, function(n)
			local tOpts = {};
			for _, s in ipairs(TCData.PHYSICAL) do
				table.insert(tOpts, { label = string.format("%s -%d, the other two -2", statShort(s), n), fn = function()
					changeStat(s, -n, true);
					for _, s2 in ipairs(TCData.PHYSICAL) do if s2 ~= s then changeStat(s2, -2, true); end end
					fnNext();
				end });
			end
			setTask({ title = "Nearly killed", text = "Reduce one physical characteristic by " .. n .. " and the other two by 2.", options = tOpts });
		end);
	elseif sOp == "injuryother" then
		return roll({ dice = "1d6", desc = "Injury for someone close (first)" }, function(a)
			roll({ dice = "1d6", desc = "Injury for someone close (second)" }, function(b)
				local n = math.min(a, b);
				note(string.format("Someone close to you was hurt: %s", TCData.INJURY[n].text));
				fnNext();
			end);
		end);
	elseif sOp == "mishap" then
		if not v then return fnNext(); end
		return doMishap(v, op.noeject, fnNext);
	elseif sOp == "life" then
		return doLifeEvent(ctx, fnNext);
	elseif sOp == "unusual" then
		return doUnusual(ctx, fnNext);
	elseif sOp == "prisoner" then
		S.forced = "prisoner";
		log("You must take the Prisoner career next term.");
		return fnNext();
	elseif sOp == "prisoner2" then
		return roll({ dice = "2d6", desc = "On a 2 you go to prison" }, function(n)
			if n == 2 then S.forced = "prisoner"; log("You rolled 2: the Prisoner career next term."); end
			fnNext();
		end);
	elseif sOp == "draft" then
		S.forced = "draft";
		log("You are drafted next term.");
		return fnNext();
	elseif sOp == "autoqual" then
		S.autoqual[op[2]] = #S.terms + 2;
		log(string.format("You may take the %s career next term without a Qualification roll.", TCData.CAREERS[op[2]].name));
		return fnNext();
	elseif sOp == "psitest" then
		return doPsiTest(fnNext);
	elseif sOp == "stay" then
		ctx.stay = true;
		return fnNext();
	elseif sOp == "eject" then
		if v then v.ejected = true; end
		return fnNext();
	elseif sOp == "noreenlist" then
		if v then v.noreenlist = true; end
		log("You may not re-enlist in this career at the end of this term.");
		return fnNext();
	elseif sOp == "check" then
		return doCheck(op, ctx, fnNext);
	elseif sOp == "t1d" then
		return roll({ dice = "1d6", desc = ctx.title or "1D" }, function(n)
			for _, r in ipairs(op[2]) do
				if n >= r[1] and n <= r[2] then return runFx(r[3], ctx, fnNext); end
			end
			fnNext();
		end);
	elseif sOp == "gamble" then
		return doGamble(op, ctx, fnNext);
	elseif sOp == "parole" then
		if v and v.parole then
			v.parole = math.max(0, math.min(12, v.parole + op[2]));
			log(string.format("Parole Threshold %+d (now %d).", op[2], v.parole));
		end
		return fnNext();
	elseif sOp == "parolereroll" then
		return roll({ dice = "1d6", mod = 4, desc = "Parole Threshold (1D+4)" }, function(n)
			if v then v.parole = math.min(12, n); log("Parole Threshold is now " .. v.parole .. "."); end
			fnNext();
		end);
	elseif sOp == "gangdm" then
		if v then v.gangdm = 1; end
		log("DM+1 to all Survival rolls in this career.");
		return fnNext();
	elseif sOp == "escape" then
		if v then v.released = true; end
		log("You escape: you leave the Prisoner career at the end of this term.");
		return fnNext();
	elseif sOp == "lawyer" then
		return doLawyer(v, fnNext);
	elseif sOp == "skillroll" then
		if not v then return fnNext(); end
		return skillTraining(v, fnNext, "A free roll on the Skills and Training tables.");
	elseif sOp == "undercover" then
		return doUndercover(op.ok, ctx, fnNext);
	elseif sOp == "navybattle" then
		return doNavyBattle(v, ctx, fnNext);
	elseif sOp == "nograd" then
		if S.education then S.education.nograd = true; end
		log("You fail to graduate.");
		return fnNext();
	elseif sOp == "wardraft" then
		return doWarDraft(fnNext);
	elseif sOp == "raiserolled" then
		if ctx.lastRolled then return gainSkill(ctx.lastRolled, nil, ctx, fnNext); end
		return fnNext();
	elseif sOp == "shares" then
		return rollCount(op[2], function(n)
			S.shares = S.shares + n;
			log(string.format("%d Ship Share%s.", n, n == 1 and "" or "s"));
			fnNext();
		end);
	elseif sOp == "benefit" then
		return addBenefit(op[2], ctx, fnNext);
	elseif sOp == "note" then
		note(op[2]);
		return fnNext();
	end
	log("(The wizard does not handle '" .. tostring(sOp) .. "': the referee settles it.)");
	fnNext();
end

-- A check: roll one of the listed skills or characteristics (the player picks).
function doCheck(op, ctx, fnNext)
	local tOpts = {};
	local tRolls = {};
	for _, sWhat in ipairs(op.rolls) do
		if sWhat == "$termskill" then
			for k in pairs((S.term and S.term.skills) or {}) do table.insert(tRolls, k); end
			if #tRolls == 0 then
				log("You have learned no skill this term to roll.");
				return runFx(op.fail, ctx, fnNext);
			end
		elseif sWhat == "$picked" then
			table.insert(tRolls, ctx.lastPicked or "Streetwise");
		else
			table.insert(tRolls, sWhat);
		end
	end
	for _, sWhat in ipairs(tRolls) do
		local nDM, sLabel;
		if sWhat == "2D" then
			nDM, sLabel = 0, "2D";
		elseif TCData.STAT_SHORT[sWhat:lower()] and #sWhat == 3 then
			nDM, sLabel = (sWhat:lower() == "psi") and TCData.getDM(S.psi or 0) or getStatDM(sWhat:lower()), sWhat;
		else
			nDM, sLabel = getSkillDM(sWhat), sWhat;
		end
		table.insert(tOpts, rollOpt(string.format("Roll %s %d+ (DM %s)", sLabel, op.target, fmtDM(nDM)),
			{ dice = "2d6", mod = nDM, target = op.target, desc = sLabel },
			function(nTotal, nNatural)
				ctx.lastRolled = (sLabel ~= "2D" and #sLabel ~= 3) and sLabel or nil;
				if nTotal >= op.target and nNatural ~= 2 then
					log(string.format("%s %d+: success (%d).", sLabel, op.target, nTotal));
					runFx(op.ok, ctx, fnNext);
				else
					log(string.format("%s %d+: failure (%d).", sLabel, op.target, nTotal));
					runFx(op.fail, ctx, function()
						if nNatural == 2 and op.two then return runFx(op.two, ctx, fnNext); end
						fnNext();
					end);
				end
			end));
	end
	setTask({ title = ctx.title or "Check", text = ctx.text or "", options = tOpts });
end

function doInjury(vMode, ctx, fnNext)
	local function apply(n)
		local e = TCData.INJURY[n];
		log("Injury: " .. e.text);
		local ctx2 = { injury = true, title = "Injury", text = e.text };
		runFx(e.fx, ctx2, function() checkCrisis(fnNext, true); end);
	end
	if type(vMode) == "number" then return apply(vMode); end
	if vMode == "lower" or vMode == "higher" then
		return roll({ dice = "1d6", desc = "Injury Table (first of two)" }, function(a)
			roll({ dice = "1d6", desc = "Injury Table (second of two)" }, function(b)
				apply(vMode == "lower" and math.min(a, b) or math.max(a, b));
			end);
		end);
	end
	roll({ dice = "1d6", desc = "Injury Table" }, function(n) apply(n); end);
end

function doMishap(v, bNoEject, fnNext)
	local c = TCData.CAREERS[v.key];
	rollStep("Mishap", "Roll on the " .. c.name .. " Mishap Table.", "Roll on the Mishap Table (1D)", { dice = "1d6", desc = c.name .. " Mishap" }, function(n)
		local e = c.mishaps[n];
		log(string.format("Mishap %d: %s", n, e.text));
		S.eventname = shortEvent(e.text);
		local ctx = { title = "Mishap " .. n, text = e.text, mishap = true };
		runFx(e.fx, ctx, function()
			if not bNoEject and not ctx.stay and not c.prison then
				v.ejected = true;
				v.ejectedThisTerm = true;
				log("You leave the " .. c.name .. " career.");
			end
			fnNext();
		end);
	end);
end

function doLifeEvent(ctx, fnNext)
	rollStep("Life Event", "Roll on the Life Events Table.", "Roll on the Life Events Table (2D)", { dice = "2d6", desc = "Life Event" }, function(n)
		local e = TCData.LIFE_EVENTS[n];
		log(string.format("Life Event %d: %s", n, e.text));
		S.eventname = shortEvent(e.text);
		runFx(e.fx, { title = "Life Event " .. n, text = e.text }, fnNext);
	end);
end

function doUnusual(ctx, fnNext)
	rollStep("Unusual Event", "Something weird happens. Roll 1D.", "Roll for the Unusual Event (1D)", { dice = "1d6", desc = "Unusual Event" }, function(n)
		local e = TCData.UNUSUAL[n];
		log(string.format("Unusual Event %d: %s", n, e.text));
		runFx(e.fx, { title = "Unusual Event " .. n, text = e.text }, fnNext);
	end);
end

-- Psionic Strength: 2D minus the terms served so far.
function doPsiTest(fnNext)
	if S.psi ~= nil then
		log("You have already been tested for psionics (PSI " .. S.psi .. ").");
		S.psiOffer = S.psi > 0;
		return fnNext();
	end
	local nTerms = #S.terms;
	setTask({ title = "Psionic test", text = string.format("You may test your Psionic Strength now: 2D minus the terms you have served (%d). With PSI 1 or more you may try the Psion career (PSI 6+) in a later term.", nTerms),
		options = {
			rollOpt(string.format("Test PSI (2D - %d)", nTerms), { dice = "2d6", mod = -nTerms, desc = "Psionic Strength" }, function(n)
				S.psi = math.max(0, n);
				S.psiOffer = S.psi > 0;
				log(string.format("Psionic Strength %d.%s", S.psi, S.psi > 0 and " You may enter the Psion career in a later term." or " No psionic potential."));
				fnNext();
			end),
			{ label = "Decline the test", fn = function() log("You decline the psionic test."); fnNext(); end },
		} });
end

function doGamble(op, ctx, fnNext)
	local v = curVisit();
	if not v then return fnNext(); end
	local nHave = math.max(0, v.benefits + v.bextra - v.blost);
	local tOpts = { { label = "Do not gamble", fn = fnNext } };
	for n = 1, nHave do
		table.insert(tOpts, { label = string.format("Wager %d Benefit roll%s", n, n == 1 and "" or "s"), fn = function()
			local tSkillOpts = {};
			for _, sSkill in ipairs(op.skills) do
				local nDM = getSkillDM(sSkill);
				table.insert(tSkillOpts, rollOpt(string.format("Roll %s 8+ (DM %s)", sSkill, fmtDM(nDM)), { dice = "2d6", mod = nDM, target = 8, desc = sSkill .. " (gamble)" }, function(nTotal)
					if nTotal >= 8 then
						v.bextra = v.bextra + math.ceil(n / 2);
						log(string.format("The gamble pays: %d extra Benefit roll(s).", math.ceil(n / 2)));
					else
						v.blost = v.blost + n;
						log(string.format("The gamble fails: %d Benefit roll(s) lost.", n));
					end
					if op.raise then return gainSkill(sSkill, nil, ctx, fnNext); end
					fnNext();
				end));
			end
			setTask({ title = "Gamble", text = ctx.text or "", options = tSkillOpts });
		end });
	end
	setTask({ title = "Gamble your Benefit rolls?", text = (ctx.text or "") .. string.format("\n\nYou have %d Benefit roll(s) from this career so far.", nHave), options = tOpts });
end

function doLawyer(v, fnNext)
	if not v or not v.parole then return fnNext(); end
	local tOpts = { { label = "Do not hire a lawyer", fn = fnNext } };
	for n = 1, 3 do
		table.insert(tOpts, rollOpt(string.format("Hire a lawyer with Advocate %d (Cr%d), roll 2D+%d", n, 1000 * n * n, n),
			{ dice = "2d6", mod = n, desc = "Your lawyer (Advocate " .. n .. ")" }, function(nTotal)
				addDebt(1000 * n * n, "lawyer");
				if nTotal > v.parole then
					v.released = true;
					log(string.format("The lawyer's roll (%d) beats your Parole Threshold (%d): you are released at the end of this term.", nTotal, v.parole));
				else
					log(string.format("The lawyer's roll (%d) does not beat your Parole Threshold (%d).", nTotal, v.parole));
				end
				fnNext();
			end));
	end
	setTask({ title = "A new lawyer", text = "The book leaves the result to the referee; the wizard compares the lawyer's roll with your Parole Threshold, as an Advancement roll would.", options = tOpts });
end

function doUndercover(bOK, ctx, fnNext)
	local tOpts = {};
	for _, sKey in ipairs({ "rogue", "citizen" }) do
		local c = TCData.CAREERS[sKey];
		if bOK then
			table.insert(tOpts, rollOpt("Roll on the " .. c.name .. " Events Table (2D)", { dice = "2d6", desc = c.name .. " Event (undercover)" }, function(n)
				local e = c.events[n];
				log(string.format("Undercover, %s Event %d: %s", c.name, n, e.text));
				runFx(e.fx, { title = c.name .. " Event " .. n, text = e.text }, function()
					local tAssign = {};
					for _, a in ipairs(c.assignments) do
						table.insert(tAssign, rollOpt("Roll on the " .. c.name .. " " .. a.name .. " table (1D)", { dice = "1d6", desc = c.name .. " " .. a.name }, function(m)
							local sSpec = c.tables[a.key][m];
							log("Skill: " .. sSpec);
							runFx(parseSpec(sSpec), { title = "Skill", text = sSpec }, fnNext);
						end));
					end
					setTask({ title = "A specialist skill", text = "Make one roll on any Specialist skill table for that career.", options = tAssign });
				end);
			end));
		else
			table.insert(tOpts, rollOpt("Roll on the " .. c.name .. " Mishap Table (1D)", { dice = "1d6", desc = c.name .. " Mishap (undercover)" }, function(n)
				local e = c.mishaps[n];
				log(string.format("Undercover, %s Mishap %d: %s", c.name, n, e.text));
				runFx(e.fx, { title = c.name .. " Mishap " .. n, text = e.text, mishap = true }, fnNext);
			end));
		end
	end
	setTask({ title = "Undercover", text = ctx.text or "", options = tOpts });
end

function doNavyBattle(v, ctx, fnNext)
	local tSkills = { line = { "Electronics (sensors)", "Gunner" }, engineer = { "Mechanic", "Vacc Suit" }, flight = { "Pilot (small craft)", "Pilot (spacecraft)", "Tactics (naval)" } };
	local op = { rolls = tSkills[v and v.assignment or "line"] or tSkills.line, target = 8,
		ok = { { "bkeep" }, { "note", "Honourably discharged from the Navy" } }, fail = { { "note", "Court-martialled and discharged from the Navy" } } };
	doCheck(op, ctx, fnNext);
end

function doWarDraft(fnNext)
	rollStep("War and the draft", TCData.PRECAREER_EVENTS[11].text, "Roll SOC 9+ to avoid the draft", { dice = "2d6", mod = getStatDM("soc"), target = 9, desc = "SOC (avoid the draft)" }, function(nTotal)
		if nTotal >= 9 then
			log("Strings are pulled: you avoid the draft and may graduate.");
			return fnNext();
		end
		if S.education then S.education.nograd = true; end
		setTask({ title = "War and the draft", text = "You do not graduate this term.", options = {
			{ label = "Flee: the Drifter career next term", fn = function() S.forced = "drifter"; log("You flee the draft: Drifter next term."); fnNext(); end },
			rollOpt("Be drafted (1D: 1-3 Army, 4-5 Marine, 6 Navy)", { dice = "1d6", desc = "War draft" }, function(n)
				local sKey = (n <= 3 and "army") or (n <= 5 and "marine") or "navy";
				S.forced = { career = sKey };
				log("Drafted into the " .. TCData.CAREERS[sKey].name .. " next term.");
				fnNext();
			end),
		} });
	end);
end

--
-- Benefits (mustering out)
--

function addDebt(n, sWhat)
	table.insert(S.debts, { amount = n, what = sWhat });
	log(string.format("Cost: Cr%d (%s).", n, sWhat));
end

function findBenefit(sName)
	for _, b in ipairs(S.benefits) do
		if b.name == sName then return b; end
	end
	return nil;
end

function addBenefit(sName, ctx, fnNext)
	local d = TCData.BENEFITS[sName];
	local v = curVisit() or (ctx and ctx.visit);
	local sFrom = v and TCData.CAREERS[v.key].name or "";
	if d.kind == "tas" then
		if S.tas then
			S.shares = S.shares + 2;
			log("TAS Membership again: two Ship Shares instead.");
		else
			S.tas = true;
			table.insert(S.benefits, { kind = "tas", name = "TAS Membership", from = sFrom });
			log("TAS Membership.");
		end
		return fnNext();
	elseif d.kind == "assoc" then
		addAssoc(d.assoc, 1);
		return fnNext();
	elseif d.kind == "ship" then
		local b = findBenefit(sName);
		if b and d.reroll then
			log("A second Scout Ship: roll again.");
			if ctx and ctx.reroll then return ctx.reroll(); end
			return fnNext();
		end
		if b and d.mortgage then
			b.paid = math.min(100, b.paid + d.mortgage);
			log(string.format("%s again: %d%% of the mortgage is paid.", b.ship, b.paid));
			return fnNext();
		end
		if b and d.againskill then
			return gainSkill(d.againskill, nil, ctx, fnNext);
		end
		table.insert(S.benefits, { kind = "ship", name = sName, ship = d.ship, paid = d.mortgage or 100, from = sFrom, mortgage = d.mortgage ~= nil, quirks = d.mortgage ~= nil });
		log(d.ship .. (d.mortgage and string.format(" (%d%% of the mortgage paid; roll 1D times on the Spacecraft Quirks Table)", d.mortgage) or "") .. ".");
		return fnNext();
	elseif d.kind == "item" then
		local b = findBenefit(sName);
		if b and d.againonly then
			log(sName .. " again: " .. d.again .. ".");
			return runFx(parseSpec(d.againskill), ctx, fnNext);
		end
		if b and d.againskill then
			return setTask({ title = sName .. " again", text = d.again .. ".", options = {
				{ label = "Another " .. sName:lower(), fn = function() table.insert(S.benefits, { kind = "item", name = sName, def = d, from = sFrom }); log("Another " .. sName:lower() .. "."); fnNext(); end },
				{ label = "One level of " .. d.againskill, fn = function() runFx(parseSpec(d.againskill), ctx, fnNext); end },
			} });
		end
		table.insert(S.benefits, { kind = "item", name = sName, def = d, from = sFrom });
		log(string.format("%s (choose one up to Cr%d, TL%d on the Benefits page).", sName, d.limit, d.tl));
		return fnNext();
	elseif d.kind == "shares" then
		S.shares = S.shares + (d.n or 1);
		log("Ship Share.");
		return fnNext();
	end
	fnNext();
end

-- Highest rank for benefits (officers commissioned after enlisted ranks add both).
function getBenefitRank(v)
	if v.officer then return v.maxorank + (v.erankAtCommission or 0); end
	return v.maxrank;
end

function musterOut(v, fnNext)
	local c = TCData.CAREERS[v.key];
	local nRank = getBenefitRank(v);
	local nRolls = v.benefits + v.bextra - v.blost + TCData.getRankBenefitRolls(math.min(6, nRank));
	if v.bloseall then nRolls = 0; end
	nRolls = math.max(0, nRolls);
	v.musteredOut = true;
	log(string.format("Mustering out of the %s career: %d term(s), rank %d; %d Benefit roll(s).", c.name, v.terms, nRank, nRolls));
	if c.pension and v.terms >= 5 then
		local n = TCData.getPension(v.terms);
		S.pension = S.pension + n;
		log(string.format("Retirement pension: Cr%d a year.", n));
	end
	v.rollsLeft = nRolls;
	local function nextRoll()
		if v.rollsLeft <= 0 then
			return fnNext();
		end
		local nRankDM = (nRank >= 5) and 1 or 0;
		local nGambler = (getSkillLevel("Gambler") ~= nil) and 1 or 0;
		local tOpts = {};
		local tTokens = { 0 };
		local tSeen = {};
		for _, n in ipairs(v.bdm) do
			if not tSeen[n] then tSeen[n] = true; table.insert(tTokens, n); end
		end
		local function useToken(n)
			if n == 0 then return; end
			for i, m in ipairs(v.bdm) do
				if m == n then table.remove(v.bdm, i); return; end
			end
		end
		for _, nTok in ipairs(tTokens) do
			local sTok = nTok > 0 and string.format(" using your DM+%d", nTok) or "";
			if S.cashRolls < 3 then
				local nDM = nRankDM + nGambler + nTok;
				table.insert(tOpts, rollOpt(string.format("Roll Cash%s (DM %s; %d of 3 cash rolls left)", sTok, fmtDM(nDM), 3 - S.cashRolls),
					{ dice = "1d6", mod = nDM, desc = c.name .. " Cash" }, function(nTotal)
						useToken(nTok);
						S.cashRolls = S.cashRolls + 1;
						local n = c.benefits.cash[math.max(1, math.min(7, nTotal))] or 0;
						S.cash = S.cash + n;
						log(string.format("Cash: Cr%d.", n));
						v.rollsLeft = v.rollsLeft - 1;
						nextRoll();
					end));
			end
			local nDM = nRankDM + nTok;
			table.insert(tOpts, rollOpt(string.format("Roll Benefits%s (DM %s)", sTok, fmtDM(nDM)),
				{ dice = "1d6", mod = nDM, desc = c.name .. " Benefits" }, function(nTotal)
					useToken(nTok);
					local function apply(nRoll)
						local sBen = c.benefits.other[math.max(1, math.min(7, nRoll))];
						log("Benefit: " .. sBen .. ".");
						local ctx = { title = "Benefit", text = sBen, visit = v };
						ctx.reroll = function()
							roll({ dice = "1d6", mod = nDM, desc = c.name .. " Benefits (roll again)" }, function(m) apply(m); end);
						end
						runFx(parseSpec(sBen), ctx, function()
							v.rollsLeft = v.rollsLeft - 1;
							nextRoll();
						end);
					end
					apply(nTotal);
				end));
		end
		setTask({ title = string.format("Mustering out: %s (%d roll%s left)", c.name, v.rollsLeft, v.rollsLeft == 1 and "" or "s"),
			text = string.format("Cash (1D):  %s\nBenefits (1D):  %s\n\nCash may be rolled only three times in your whole life. DM+1 to both columns at rank 5 or 6; DM+1 to Cash with the Gambler skill.",
				describeColumn(c.benefits.cash, true), describeColumn(c.benefits.other)),
			options = tOpts });
	end
	nextRoll();
end

function describeColumn(t, bCash)
	local tOut = {};
	for i, x in ipairs(t) do
		table.insert(tOut, string.format("%d %s", i, bCash and ((x == 0) and "none" or ("Cr" .. x)) or x));
	end
	return table.concat(tOut, ", ");
end

--
-- Careers: qualification and the term engine
--

function curVisit()
	return S.cur and S.visits[S.cur] or nil;
end

function getPreviousCareerCount(sKey)
	local tSeen = {};
	local n = 0;
	for _, v in ipairs(S.visits) do
		if v.key ~= sKey and not tSeen[v.key] then
			tSeen[v.key] = true;
			n = n + 1;
		end
	end
	return n;
end

-- Best qualification stat, target and every DM, as text.
function getQualification(sKey)
	local c = TCData.CAREERS[sKey];
	local sBest, nTarget, nBest = nil, 0, -99;
	for _, q in ipairs(c.qual or {}) do
		local nDM = (q[1] == "psi") and TCData.getDM(S.psi or 0) or getStatDM(q[1]);
		if nDM > nBest then sBest, nTarget, nBest = q[1], q[2], nDM; end
	end
	local nDM = (nBest > -99) and nBest or 0;
	local tParts = {};
	if sBest then table.insert(tParts, string.format("%s DM %s", statShort(sBest), fmtDM(nBest))); end
	local nPrev = getPreviousCareerCount(sKey);
	if nPrev > 0 then nDM = nDM - nPrev; table.insert(tParts, string.format("previous careers -%d", nPrev)); end
	if c.agedm and getAge() >= c.agedm[1] then nDM = nDM + c.agedm[2]; table.insert(tParts, string.format("age %d+ %d", c.agedm[1], c.agedm[2])); end
	if S.mods.qdm ~= 0 then nDM = nDM + S.mods.qdm; table.insert(tParts, string.format("events %s", fmtDM(S.mods.qdm))); end
	local e = S.education;
	local nUni, sUniOnly = 0, nil;
	if e and e.kind == "university" and e.grad then
		for _, sC in ipairs(TCData.UNIVERSITY.careerdm) do
			if sC:match("^[^:]+") == sKey then
				nUni = e.honours and 2 or 1;
				sUniOnly = sC:match(":(.+)$");
				nDM = nDM + nUni;
				table.insert(tParts, string.format("university %+d%s", nUni, sUniOnly and (" (" .. sUniOnly .. " assignment)") or ""));
				break;
			end
		end
	end
	return sBest, nTarget, nDM, table.concat(tParts, ", "), nUni, sUniOnly;
end

function isAutoQual(sKey)
	local c = TCData.CAREERS[sKey];
	if c.autoqual then return true, "automatic"; end
	if c.socauto and getStat("soc") >= c.socauto then return true, "automatic with SOC " .. c.socauto .. "+"; end
	if S.autoqual[sKey] and S.autoqual[sKey] == #S.terms + 1 then return true, "no roll needed this term"; end
	local e = S.education;
	if e and e.kind == "academy" and e.branch == sKey and e.firstCareerPending and (e.grad or not e.failedTwo) then
		return true, "academy entry";
	end
	return false;
end

function getAge()
	return 18 + 4 * #S.terms;
end

function beginTerm()
	if S.done then return refresh(); end
	local f = S.forced;
	local vOld = curVisit();
	if f and vOld and not vOld.musteredOut and not TCData.CAREERS[vOld.key].prison then
		-- Events send you elsewhere: leave the old career properly first.
		S.term = nil;
		return musterOut(vOld, function() S.lastLeft = { key = vOld.key, term = #S.terms }; S.cur = nil; beginTerm(); end);
	end
	local n = #S.terms + 1;
	S.term = { n = n, lines = {}, skills = {} };
	log(string.format("=== Term %d (age %d) ===", n, getAge()));
	S.forced = nil;
	if f == "prisoner" then
		log("You serve this term in prison.");
		return enterCareer("prisoner", nil, { forced = true });
	elseif f == "draft" then
		return doDraft(true);
	elseif f == "drifter" then
		return enterCareer("drifter");
	elseif type(f) == "table" then
		return enterCareer(f.career, f.assignment, { drafted = true });
	end
	local v = curVisit();
	if v then
		return continueCareer(v);
	end
	chooseNext();
end

function chooseNext(bNoEducation)
	local n = #S.terms + 1;
	local tOpts = {};
	local e = S.education;
	if not bNoEducation and n <= 3 and not (e and e.done) and not (S.term and S.term.educationTried) then
		local tU = TCData.UNIVERSITY;
		local nDM = getStatDM("edu") - ((n == 2) and 1 or 0) - ((n == 3) and 2 or 0) + ((getStat("soc") >= 9) and 1 or 0);
		table.insert(tOpts, { label = string.format("University (EDU %d+, DM %s)", R().uniEntry, fmtDM(nDM)), tip = tU.text, fn = function() startEducation("university"); end });
		for _, sKey in ipairs({ "army", "marine", "navy" }) do
			local a = TCData.ACADEMIES[sKey];
			local nADM = getStatDM(a.entry[1]) - ((n == 2) and 2 or 0) - ((n == 3) and 4 or 0);
			table.insert(tOpts, { label = string.format("%s (%s %d+, DM %s)", a.name, statShort(a.entry[1]), R().academy[sKey], fmtDM(nADM)), fn = function() startEducation("academy", sKey); end });
		end
	end
	for _, sKey in ipairs(TCData.CAREER_ORDER) do
		local c = TCData.CAREERS[sKey];
		if not c.forced and (not c.needpsi or S.psiOffer) then
			local sStat, nTarget, nDM = getQualification(sKey);
			local bAuto, sWhy = isAutoQual(sKey);
			local sLabel;
			if bAuto then
				sLabel = string.format("%s (%s)", c.name, sWhy);
			else
				sLabel = string.format("%s (%s %d+, DM %s)", c.name, statShort(sStat or "int"), nTarget, fmtDM(nDM));
			end
			local bBlocked = S.lastLeft and S.lastLeft.key == sKey and S.lastLeft.term == #S.terms and sKey ~= "drifter";
			if bBlocked then sLabel = sLabel .. "  - left it last term"; end
			if S.crisis and not c.autoqual then sLabel = sLabel .. "  - fails (ageing crisis)"; end
			table.insert(tOpts, { label = sLabel, tip = c.text, disabled = bBlocked, fn = function() qualify(sKey); end });
		end
	end
	if n > 1 then
		table.insert(tOpts, { label = "Stop here and begin your life of adventure", fn = function() finishCareers(); end });
	end
	local tAnag = getAnagathicsOptions(function() chooseNext(bNoEducation); end);
	for _, o in ipairs(tAnag) do table.insert(tOpts, o); end
	setTask({ title = string.format("Term %d (age %d): what next?", n, getAge()),
		text = "Choose a career to try for. The roll you need and your DM are on each button; a failed Qualification roll means the Draft (once in your life) or the Drifter career. University and the military academies are open in terms 1 to 3." ..
			(n > 1 and "\n\nOr stop here: your Traveller is ready for play." or ""),
		options = tOpts });
end

function qualify(sKey)
	local c = TCData.CAREERS[sKey];
	local e = S.education;
	if e and e.firstCareerPending then
		e.firstCareerPending = false;
		e.firstCareer = sKey;
	end
	local bAuto = isAutoQual(sKey);
	if bAuto then
		log("No Qualification roll needed for the " .. c.name .. " career.");
		return enterCareer(sKey);
	end
	if S.crisis then
		log("After your ageing crisis you automatically fail any Qualification roll.");
		return failQual(sKey);
	end
	local sStat, nTarget, nDM, sParts, nUni, sUniOnly = getQualification(sKey);
	rollStep("Qualification: " .. c.name, c.text .. "\n\nQualification: " .. statShort(sStat) .. " " .. nTarget .. "+ (" .. sParts .. ")",
		string.format("Roll to qualify (%s %d+, DM %s)", statShort(sStat), nTarget, fmtDM(nDM)),
		{ dice = "2d6", mod = nDM, target = nTarget, desc = c.name .. " Qualification" }, function(nTotal)
			S.mods.qdm = 0;
			if nTotal >= nTarget then
				log(string.format("You qualify for the %s career (%d).", c.name, nTotal));
				-- The university DM counts only for one assignment (Citizen corporate,
				-- Entertainer journalist): if it made the difference, that is the assignment.
				if sUniOnly and nTotal - nUni < nTarget then
					local sA = sUniOnly == "corporate" and "corporate" or sUniOnly;
					log("Your degree got you in: you take the " .. sUniOnly .. " assignment.");
					return enterCareer(sKey, sA);
				end
				enterCareer(sKey);
			else
				log(string.format("You fail to qualify for the %s career (%d).", c.name, nTotal));
				failQual(sKey);
			end
		end);
end

function failQual(sKey)
	local tOpts = {};
	if not S.draftUsed then
		table.insert(tOpts, rollOpt("Submit to the Draft (1D)", { dice = "1d6", desc = "Draft" }, function(n) applyDraft(n); end,
			"1 Navy, 2 Army, 3 Marine, 4 Merchant (merchant marine), 5 Scout, 6 Agent (law enforcement). Once in your life."));
	end
	table.insert(tOpts, { label = "Become a Drifter", fn = function() enterCareer("drifter"); end });
	setTask({ title = "Not accepted", text = "You cannot enter that career this term. Submit to the Draft (once in your life) or drift." .. (S.draftUsed and "\n\nYou have already been through the Draft." or ""), options = tOpts });
end

function doDraft(bForced)
	rollStep("The Draft", "You are drafted into one of the services. Roll 1D: 1 Navy, 2 Army, 3 Marine, 4 Merchant (merchant marine), 5 Scout, 6 Agent (law enforcement).",
		"Roll for the Draft (1D)", { dice = "1d6", desc = "Draft" }, function(n) applyDraft(n, bForced); end);
end

function applyDraft(n, bForced)
	if not bForced then S.draftUsed = true; end
	local d = TCData.DRAFT[n];
	log(string.format("Drafted (%d): %s.", n, TCData.CAREERS[d.career].name));
	enterCareer(d.career, d.assignment, { drafted = true });
end

function startEducation(sKind, sBranch)
	S.term.educationTried = true;
	local n = #S.terms + 1;
	if sKind == "university" then
		local nDM = getStatDM("edu") - ((n == 2) and 1 or 0) - ((n == 3) and 2 or 0) + ((getStat("soc") >= 9) and 1 or 0);
		local nT = R().uniEntry;
		rollStep("University", TCData.UNIVERSITY.text .. string.format("\n\nEntry: EDU %d+ (DM-1 in term two, DM-2 in term three, DM+1 with SOC 9+).", nT),
			string.format("Roll for entry (EDU %d+, DM %s)", nT, fmtDM(nDM)), { dice = "2d6", mod = nDM, target = nT, desc = "University entry" }, function(nTotal)
				if nTotal < nT then
					log("You are not accepted at university: you must try a career now.");
					return chooseNext(true);
				end
				S.education = { kind = "university", term = n };
				S.term.kind = "education";
				log("You enter university.");
				universitySkills();
			end);
	else
		local a = TCData.ACADEMIES[sBranch];
		a = { name = a.name, entry = { a.entry[1], R().academy[sBranch] } };
		local nDM = getStatDM(a.entry[1]) - ((n == 2) and 2 or 0) - ((n == 3) and 4 or 0);
		rollStep(a.name, string.format("For those who are looking to dedicate their lives to military service. Entry: %s %d+ (DM-2 in term two, DM-4 in term three).", statShort(a.entry[1]), a.entry[2]),
			string.format("Roll for entry (%s %d+, DM %s)", statShort(a.entry[1]), a.entry[2], fmtDM(nDM)), { dice = "2d6", mod = nDM, target = a.entry[2], desc = a.name .. " entry" }, function(nTotal)
				if nTotal < a.entry[2] then
					log("You are not accepted at the academy: you must try a career now.");
					return chooseNext(true);
				end
				S.education = { kind = "academy", branch = sBranch, term = n };
				S.term.kind = "education";
				log("You enter the " .. a.name .. ".");
				local c = TCData.CAREERS[sBranch];
				basicSkills(c.tables.service, true, function() educationEvent(); end);
			end);
	end
end

function universitySkills()
	local tList = TCData.UNIVERSITY.skills;
	local tOpts = {};
	for _, s in ipairs(tList) do
		table.insert(tOpts, { label = s, fn = function()
			S.education.skill0 = s;
			local tOpts1 = {};
			for _, s1 in ipairs(tList) do
				if s1 ~= s then
					table.insert(tOpts1, { label = s1, fn = function()
						S.education.skill1 = s1;
						gainSkill(s, 0, nil, function()
							gainSkill(s1, 1, nil, function()
								changeStat("edu", 1);
								educationEvent();
							end);
						end);
					end });
				end
			end
			setTask({ title = "University: a level 1 skill", text = "Choose a level 1 skill (graduation raises it to 2).", options = tOpts1, grid = true });
		end });
	end
	setTask({ title = "University: a level 0 skill", text = "Choose a level 0 skill and a level 1 skill from the list (graduation raises them to 1 and 2). EDU +1.", options = tOpts, grid = true });
end

function educationEvent()
	rollStep("Pre-career event", "Roll on the Pre-Career Events Table.", "Roll for an event (2D)", { dice = "2d6", desc = "Pre-career Event" }, function(n)
		local e = TCData.PRECAREER_EVENTS[n];
		log(string.format("Event %d: %s", n, e.text));
		S.eventname = shortEvent(e.text);
		runFx(e.fx, { title = "Event " .. n, text = e.text }, graduation);
	end);
end

function graduation()
	local e = S.education;
	if e.nograd or S.forced then
		e.done = true;
		log("You do not graduate.");
		return endEducationTerm();
	end
	if e.kind == "university" then
		local r = R();
		rollStep("Graduation", string.format("Graduation: INT %d+. %d+ graduates with honours. Graduates raise their two skills to 1 and 2, gain EDU +%d, DM+1 (honours DM+2) to qualify for Agent, Army, Citizen (corporate), Entertainer (journalist), Marines, Navy, Scholar and Scouts, and may roll for a commission before their first military term.", r.uniGrad, r.uniHonours, r.uniGradEdu),
			string.format("Roll to graduate (INT %d+, DM %s)", r.uniGrad, fmtDM(getStatDM("int"))), { dice = "2d6", mod = getStatDM("int"), target = r.uniGrad, desc = "University graduation" }, function(nTotal)
				e.done = true;
				if nTotal >= r.uniGrad then
					e.grad = true;
					e.honours = nTotal >= r.uniHonours;
					e.firstCareerPending = true;
					log(e.honours and "You graduate with honours." or "You graduate.");
					gainSkill(e.skill0, 1, nil, function()
						gainSkill(e.skill1, 2, nil, function()
							changeStat("edu", r.uniGradEdu);
							endEducationTerm();
						end);
					end);
				else
					log("You fail to graduate.");
					endEducationTerm();
				end
			end);
	else
		local nDM = getStatDM("int") + ((getStat("end") >= 8) and 1 or 0) + ((getStat("soc") >= 8) and 1 or 0);
		local r = R();
		rollStep("Graduation", string.format("Graduation: INT %d+ (DM+1 with END 8+, DM+1 with SOC 8+). %d+ graduates with honours. Graduates gain EDU +1 (honours: SOC +1 too), enter the academy's service automatically as their first career, raise three Service Skills to 1 there, and roll for a commission before their first term with DM+2 (honours: automatic).", r.academyGrad, r.academyHonours),
			string.format("Roll to graduate (INT %d+, DM %s)", r.academyGrad, fmtDM(nDM)), { dice = "2d6", mod = nDM, target = r.academyGrad, desc = "Academy graduation" }, function(nTotal, nNatural)
				e.done = true;
				e.firstCareerPending = true;
				if nTotal >= r.academyGrad then
					e.grad = true;
					e.honours = nTotal >= r.academyHonours;
					log(e.honours and "You graduate with honours." or "You graduate.");
					changeStat("edu", 1);
					if e.honours then changeStat("soc", 1); end
				else
					e.failedTwo = (nNatural == 2);
					log(e.failedTwo and "You fail to graduate (a natural 2: no automatic entry)." or "You fail to graduate, but may still enter the service automatically (no commission in the first term).");
				end
				endEducationTerm();
			end);
	end
end

function endEducationTerm()
	S.term.kind = "education";
	S.term.label = (S.education.kind == "university") and "University" or TCData.ACADEMIES[S.education.branch].name;
	table.insert(S.terms, S.term);
	S.term = nil;
	beginTerm();
end

-- Level-0 skills from a table (basic training): all of them, or one chosen.
function basicSkills(tTable, bAll, fnNext)
	if bAll then
		local i = 0;
		local function step()
			i = i + 1;
			if i > #tTable then return fnNext(); end
			local sSpec = tTable[i];
			-- "Pilot (small craft) or Pilot (spacecraft)" at level 0 is simply Pilot 0.
			local tBases, nBases = {}, 0;
			for sPart in (sSpec .. " or "):gmatch("(.-) or ") do
				if not tBases[baseOf(sPart)] then tBases[baseOf(sPart)] = true; nBases = nBases + 1; end
			end
			if sSpec:find(" or ") and nBases == 1 then
				return basicOne(baseOf(sSpec:match("^(.-) or ")), step);
			end
			if sSpec:find(" or ") then
				local tOpts = {};
				for sPart in (sSpec .. " or "):gmatch("(.-) or ") do
					table.insert(tOpts, { label = baseOf(sPart) .. " 0", fn = function() basicOne(sPart, step); end });
				end
				return setTask({ title = "Basic training", text = sSpec .. ": choose one at level 0.", options = tOpts });
			end
			basicOne(sSpec, step);
		end
		return step();
	end
	local tOpts = {};
	local tSeen = {};
	for _, sSpec in ipairs(tTable) do
		for sPart in (sSpec .. " or "):gmatch("(.-) or ") do
			local sB = baseOf(sPart);
			if not tSeen[sB] then
				tSeen[sB] = true;
				table.insert(tOpts, { label = sB .. " 0" .. (S.skills[sB] ~= nil and "  (you have it)" or ""), fn = function() basicOne(sPart, fnNext); end });
			end
		end
	end
	setTask({ title = "Basic training", text = "For a later career you pick one skill from the Service Skills table at level 0.", options = tOpts });
end

function basicOne(sSpec, fnNext)
	local s = trim(sSpec);
	if s:match("^%a%a%a [+-]%d$") then return fnNext(); end
	if isTalent(s) or s == "Any Talent" then
		if s == "Any Talent" then return fnNext(); end
		return gainTalent(baseOf(s), 0, fnNext);
	end
	local sName = specOf(s) and s or baseOf(s);
	if S.skills[sName] == nil then
		setSkillLevel(sName, 0, "basic training");
	end
	fnNext();
end

function enterCareer(sKey, sAssign, tOpts)
	tOpts = tOpts or {};
	local c = TCData.CAREERS[sKey];
	local function withAssignment(sA)
		local bFirstCareer = true;
		for _, v0 in ipairs(S.visits) do
			if v0.key ~= "prisoner" then bFirstCareer = false; end
		end
		local v = { key = sKey, assignment = sA, terms = 0, rank = 0, maxrank = 0, officer = false, orank = 0, maxorank = 0,
			benefits = 0, bextra = 0, blost = 0, bdm = {}, startTerm = #S.terms + 1, drafted = tOpts.drafted };
		table.insert(S.visits, v);
		S.cur = #S.visits;
		S.term.kind = "career";
		log(string.format("You enter the %s career (%s).", c.name, getAssignment(v).name));
		if c.prison then
			roll({ dice = "1d6", mod = 4, desc = "Parole Threshold (1D+4)" }, function(n)
				v.parole = math.min(12, n);
				log("Your Parole Threshold is " .. v.parole .. ".");
			end);
		end
		local function afterBasicStart()
			local tTable = (c.basic == "assignment") and c.tables[sA] or c.tables.service;
			local e = S.education;
			local bAcademyGrad = e and e.kind == "academy" and e.grad and e.branch == sKey and e.firstCareer == sKey and not e.used;
			local function afterBasic()
				if bAcademyGrad then
					return academyBonus(c, function() rankBonus(v, 0, false, function() preCommission(v, termBody); end); end);
				end
				rankBonus(v, 0, false, function() preCommission(v, termBody); end);
			end
			log(bFirstCareer and "Basic training: every skill on the table at level 0." or "Basic training: one skill at level 0.");
			basicSkills(tTable, bFirstCareer, afterBasic);
		end
		-- No anagathics in prison; stopping them means an Ageing roll at once.
		if c.prison and S.anag.on then
			S.anag.on = false;
			log("Prisoners may not use anagathics: you stop, and roll on the Ageing Table at once.");
			local fnBasic = afterBasicStart;
			local nDM = -#S.terms;
			return rollStep("Ageing", "Prisoners may not use anagathics. Coming off them, you roll on the Ageing Table at once.",
				string.format("Roll for ageing (2D, DM %s)", fmtDM(nDM)), { dice = "2d6", mod = nDM, desc = "Ageing (anagathics stopped)" }, function(nTotal)
					local e = TCData.AGEING[math.max(-6, math.min(1, nTotal))];
					log("Ageing: " .. e.text);
					applyAgeing(e, fnBasic);
				end);
		end
		afterBasicStart();
	end
	if sAssign then return withAssignment(sAssign); end
	local tA = {};
	for _, a in ipairs(c.assignments) do
		table.insert(tA, { label = string.format("%s: Survival %s %d+, Advancement %s %d+", a.name, statShort(a.surv[1]), a.surv[2], statShort(a.adv[1]), a.adv[2]),
			tip = a.text, fn = function() withAssignment(a.key); end });
	end
	setTask({ title = c.name .. ": choose an assignment", text = c.text .. "\n\n" .. describeAssignments(c), options = tA });
end

function describeAssignments(c)
	local t = {};
	for _, a in ipairs(c.assignments) do table.insert(t, a.name .. ": " .. a.text); end
	return table.concat(t, "\n");
end

function getAssignment(v)
	for _, a in ipairs(TCData.CAREERS[v.key].assignments) do
		if a.key == v.assignment then return a; end
	end
	return TCData.CAREERS[v.key].assignments[1];
end

-- Military academy graduates entering their service: three Service Skills to 1.
function academyBonus(c, fnNext)
	S.education.used = true;
	local nLeft = 3;
	local tTaken = {};
	local function pickOne()
		if nLeft <= 0 then return fnNext(); end
		local tOpts = {};
		for _, sSpec in ipairs(c.tables.service) do
			for sPart in (sSpec .. " or "):gmatch("(.-) or ") do
				local sB = trim(sPart);
				if not tTaken[sB] then
					table.insert(tOpts, { label = sB .. " 1", fn = function()
						tTaken[sB] = true;
						nLeft = nLeft - 1;
						gainSkill(sB, 1, nil, pickOne);
					end });
				end
			end
		end
		setTask({ title = string.format("Academy graduate: %d Service Skill(s) to level 1", nLeft), text = "As a graduate entering the service your academy is tied to, raise three Service Skills to level 1.", options = tOpts });
	end
	pickOne();
end

function getRankEntry(v, nRank, bOfficer)
	local c = TCData.CAREERS[v.key];
	local t = bOfficer and c.ranks.officer or (c.ranks[v.assignment] or c.ranks.default);
	return t and t[nRank];
end

function getRankTitle(v)
	local r = getRankEntry(v, v.officer and v.orank or v.rank, v.officer);
	return r and r[1] or "";
end

-- The bonus for reaching a rank (each once per career and track).
function rankBonus(v, nRank, bOfficer, fnNext)
	local r = getRankEntry(v, nRank, bOfficer);
	local sKey = v.key .. ":" .. (bOfficer and "officer" or (v.assignment or "")) .. ":" .. nRank;
	if not r or not r[2] or S.rankBonusGiven[sKey] then return fnNext(); end
	S.rankBonusGiven[sKey] = true;
	local vBonus = r[2];
	if type(vBonus) == "table" then
		log("Rank bonus.");
		return runFx(vBonus, { title = "Rank bonus" }, fnNext);
	end
	log(string.format("Rank %d%s bonus: %s.", nRank, (r[1] ~= "" and (" (" .. r[1] .. ")") or ""), vBonus));
	runFx(parseSpec(vBonus), { title = "Rank bonus", text = vBonus }, fnNext);
end

-- University and academy graduates may roll for a commission before their first military term.
function preCommission(v, fnNext)
	local c = TCData.CAREERS[v.key];
	local e = S.education;
	if not c.commission or not e or not e.grad or e.precommDone or e.firstCareer ~= v.key or v.terms > 0 then return fnNext(); end
	e.precommDone = true;
	local nDM = getStatDM(c.commission[1]);
	if e.kind == "academy" then
		if e.honours then
			log("Academy honours: you are commissioned automatically.");
			return becomeOfficer(v, fnNext);
		end
		nDM = nDM + 2;
	elseif e.honours then
		nDM = nDM + 2;
	end
	setTask({ title = "Commission before your first term", text = "As a graduate you may roll for a commission before your first term. Success means you start as an officer (rank O1).",
		options = {
			rollOpt(string.format("Roll for a commission (%s %d+, DM %s)", statShort(c.commission[1]), c.commission[2], fmtDM(nDM)),
				{ dice = "2d6", mod = nDM, target = c.commission[2], desc = c.name .. " Commission" }, function(nTotal)
					if nTotal >= c.commission[2] then
						log("You are commissioned.");
						return becomeOfficer(v, fnNext);
					end
					log("No commission.");
					fnNext();
				end),
			{ label = "Do not apply", fn = fnNext },
		} });
end

function becomeOfficer(v, fnNext)
	v.officer = true;
	v.erankAtCommission = v.rank;
	v.orank = 1;
	v.maxorank = math.max(v.maxorank, 1);
	log("You are now an officer: " .. getRankTitle(v) .. ".");
	rankBonus(v, 1, true, fnNext);
end

function continueCareer(v)
	local c = TCData.CAREERS[v.key];
	log(string.format("You continue in the %s career (%s), term %d there.", c.name, getAssignment(v).name, v.terms + 1));
	termBody();
end

function termBody()
	local v = curVisit();
	v.autoPromote = false;
	v.autoCommission = false;
	v.ejectedThisTerm = false;
	skillTraining(v, function()
		survival(v, function(bSurvived)
			if not bSurvived then
				return doMishap(v, false, function() endTerm(true); end);
			end
			careerEvent(v, function()
				if v.ejectedThisTerm then return endTerm(true); end
				commission(v, function()
					advancement(v, function() endTerm(false); end);
				end);
			end);
		end);
	end);
end

function skillTraining(v, fnNext, sWhy)
	local c = TCData.CAREERS[v.key];
	local a = getAssignment(v);
	local tOpts = {};
	local function add(sKey, sName, sNote)
		local t = c.tables[sKey];
		if not t then return; end
		local tLines = {};
		for i = 1, 6 do table.insert(tLines, i .. " " .. t[i]); end
		table.insert(tOpts, rollOpt(sName .. (sNote or ""), { dice = "1d6", desc = c.name .. " " .. sName }, function(n)
			local sSpec = t[n];
			log(string.format("%s %d: %s.", sName, n, sSpec));
			runFx(parseSpec(sSpec), { title = sName, text = sSpec }, fnNext);
		end, table.concat(tLines, "\n")));
		tOpts[#tOpts].detail = table.concat(tLines, ", ");
	end
	add("personal", "Personal Development");
	add("service", "Service Skills");
	add(v.assignment, a.name);
	if c.tables.advanced then
		local nMin = c.tables.advanced.min or 8;
		if getStat("edu") >= nMin then
			add("advanced", "Advanced Education", string.format(" (EDU %d+)", nMin));
		end
	end
	if v.officer and c.tables.officer then add("officer", "Officer"); end
	setTask({ title = "Skills and Training", text = (sWhy or "Pick a table and roll 1D for a skill this term.") .. string.format("\n\nSkills cannot pass 4 during creation, and all your levels together cannot pass 3 x (INT + EDU) = %d (you have %d).", getSkillLimit(), getTotalSkillLevels()),
		options = tOpts, detailed = true });
end

function survival(v, fnNext)
	local c = TCData.CAREERS[v.key];
	local a = getAssignment(v);
	local nDM = getStatDM(a.surv[1]) + S.mods.sdm + (v.gangdm or 0);
	local sParts = string.format("%s DM %s", statShort(a.surv[1]), fmtDM(getStatDM(a.surv[1])));
	if S.mods.sdm ~= 0 then sParts = sParts .. string.format(", events %s", fmtDM(S.mods.sdm)); end
	if v.gangdm then sParts = sParts .. ", gang +1"; end
	local nRolls = S.anag.on and 2 or 1;
	local nDone, bOK = 0, true;
	local function one()
		rollStep("Survival", string.format("%s (%s): Survival %s %d+ (%s). A natural 2 always fails.%s", c.name, a.name, statShort(a.surv[1]), a.surv[2], sParts, nRolls == 2 and "\n\nOn anagathics you must make two Survival rolls." or ""),
			string.format("Roll Survival (%s %d+, DM %s)%s", statShort(a.surv[1]), a.surv[2], fmtDM(nDM), nRolls == 2 and string.format(" %d of 2", nDone + 1) or ""),
			{ dice = "2d6", mod = nDM, target = a.surv[2], desc = c.name .. " Survival" }, function(nTotal, nNatural)
				nDone = nDone + 1;
				if nTotal < a.surv[2] or nNatural == 2 then bOK = false; end
				if nDone < nRolls then return one(); end
				S.mods.sdm = 0;
				log(bOK and "You survive the term." or "Survival failed: a mishap.");
				fnNext(bOK);
			end);
	end
	one();
end

function careerEvent(v, fnNext)
	local c = TCData.CAREERS[v.key];
	rollStep("Event", "Roll on the " .. c.name .. " Events Table.", "Roll for an event (2D)", { dice = "2d6", desc = c.name .. " Event" }, function(n)
		local e = c.events[n];
		local sText = e.text;
		if e.prisonevent then sText = sText .. "\n" .. table.concat(e.prisonevent, "\n"); end
		log(string.format("Event %d: %s", n, e.text));
		S.eventname = shortEvent(e.text);
		runFx(e.fx, { title = "Event " .. n, text = sText }, function() S.eventname = nil; fnNext(); end);
	end);
end

function commission(v, fnNext)
	local c = TCData.CAREERS[v.key];
	if not c.commission or v.officer then return fnNext(); end
	if v.autoCommission then
		log("Commissioned automatically.");
		return becomeOfficer(v, fnNext);
	end
	local e = S.education;
	if e and e.kind == "academy" and not e.grad and e.firstCareer == v.key and v.terms == 0 then
		return fnNext();
	end
	if v.terms > 0 and getStat("soc") < 9 then return fnNext(); end
	local nDM = getStatDM(c.commission[1]) - v.terms;
	local tOpts = {};
	local function addRoll(nExtra, sNote)
		table.insert(tOpts, rollOpt(string.format("Roll for a commission (%s %d+, DM %s)%s", statShort(c.commission[1]), c.commission[2], fmtDM(nDM + nExtra), sNote or ""),
			{ dice = "2d6", mod = nDM + nExtra, target = c.commission[2], desc = c.name .. " Commission" }, function(nTotal)
				if nExtra ~= 0 then S.mods.adm = 0; end
				if nTotal >= c.commission[2] then
					log("You are commissioned.");
					return becomeOfficer(v, fnNext);
				end
				log("No commission this term.");
				fnNext();
			end));
	end
	if S.autopass then
		table.insert(tOpts, { label = "Take the commission (your automatic pass)", fn = function() S.autopass = false; log("Commissioned (automatic pass)."); becomeOfficer(v, fnNext); end });
	end
	addRoll(0);
	if S.mods.adm ~= 0 then addRoll(S.mods.adm, string.format(" using your Advancement DM %s", fmtDM(S.mods.adm))); end
	table.insert(tOpts, { label = "Do not try for a commission", fn = fnNext });
	setTask({ title = "Commission", text = string.format("You may try for a commission (optional): %s %d+, DM-1 for every term after the first in this career. You may try in your first term, or in any term with SOC 9+. An officer becomes rank 1 and uses the officer ranks and Officer skill table.", statShort(c.commission[1]), c.commission[2]),
		options = tOpts });
end

function advancement(v, fnNext)
	local c = TCData.CAREERS[v.key];
	local a = getAssignment(v);
	local nTermsHere = v.terms + 1;
	local function promote(fnAfter)
		if v.officer then
			v.orank = math.min(6, v.orank + 1);
			v.maxorank = math.max(v.maxorank, v.orank);
		else
			v.rank = math.min(6, v.rank + 1);
			v.maxrank = math.max(v.maxrank, v.rank);
		end
		log(string.format("Promoted to rank %s%d%s.", v.officer and "O" or "", v.officer and v.orank or v.rank, getRankTitle(v) ~= "" and (" (" .. getRankTitle(v) .. ")") or ""));
		rankBonus(v, v.officer and v.orank or v.rank, v.officer, function()
			skillTraining(v, fnAfter, "Promotion: an extra roll on the Skills and Training tables.");
		end);
	end
	if v.autoPromote then
		v.autoPromote = false;
		return promote(fnNext);
	end
	local nDM = getStatDM(a.adv[1]) + S.mods.adm;
	local sText;
	if c.prison then
		sText = string.format("Advancement %s %d+ (DM %s). Your Parole Threshold is %d: a roll above it releases you at the end of this term.", statShort(a.adv[1]), a.adv[2], fmtDM(nDM), v.parole or 0);
	else
		sText = string.format("Advancement %s %d+ (DM %s). Success: the next rank and an extra Skills roll. A roll of %d or less (the terms you have spent here) means you must leave after this term; a natural 12 means you must stay.", statShort(a.adv[1]), a.adv[2], fmtDM(nDM), nTermsHere);
	end
	local tOpts = {};
	if S.autopass and not c.prison then
		table.insert(tOpts, { label = "Take the promotion (your automatic pass)", fn = function() S.autopass = false; log("Promoted (automatic pass)."); promote(fnNext); end });
	end
	table.insert(tOpts, rollOpt(string.format("Roll Advancement (%s %d+, DM %s)", statShort(a.adv[1]), a.adv[2], fmtDM(nDM)),
		{ dice = "2d6", mod = nDM, target = a.adv[2], desc = c.name .. " Advancement" }, function(nTotal, nNatural)
			S.mods.adm = 0;
			if c.prison then
				if v.parole and nTotal > v.parole then
					v.released = true;
					log(string.format("Advancement %d beats your Parole Threshold %d: released at the end of the term.", nTotal, v.parole));
				else
					log(string.format("Advancement %d: still inside (Parole Threshold %d).", nTotal, v.parole or 0));
				end
				if nTotal >= a.adv[2] then return promote(fnNext); end
				return fnNext();
			end
			if nNatural == 12 then
				v.mustStay = true;
				log("A natural 12: you must continue in this career.");
			elseif nTotal <= nTermsHere then
				v.mustLeave = true;
				log(string.format("Advancement %d is no more than your %d term(s) here: you must leave after this term.", nTotal, nTermsHere));
			end
			if nTotal >= a.adv[2] then return promote(fnNext); end
			log("No promotion this term.");
			fnNext();
		end));
	setTask({ title = "Advancement", text = sText, options = tOpts });
end

function endTerm(bMishap)
	local v = curVisit();
	local c = TCData.CAREERS[v.key];
	v.terms = v.terms + 1;
	if not bMishap or v.keepbenefit then
		v.benefits = v.benefits + 1;
	end
	v.keepbenefit = false;
	S.term.kind = "career";
	S.term.label = string.format("%s (%s)", c.name, getAssignment(v).name);
	S.term.visit = S.cur;
	table.insert(S.terms, S.term);
	local function afterAgeing()
		S.term = nil;
		endTermDecision(v, bMishap);
	end
	local function afterAnag()
		if #S.terms >= 4 then return ageing(afterAgeing); end
		afterAgeing();
	end
	if S.anag.on then
		S.anag.terms = S.anag.terms + 1;
		local nCost = R().anagathicsCost;
		return roll({ dice = "1d6", desc = string.format("Anagathics cost (1D x Cr%d)", nCost), mult = nCost }, function(n)
			addDebt(n * nCost, "anagathics, term " .. #S.terms);
			afterAnag();
		end);
	end
	afterAnag();
end

function ageing(fnNext)
	-- Terms on anagathics count in your favour only while you are still taking them.
	local nOnAnag = S.anag.on and S.anag.terms or 0;
	local nDM = -#S.terms + nOnAnag;
	rollStep("Ageing", string.format("From the end of your fourth term you roll 2D on the Ageing Table each term: DM -%d for your terms%s.", #S.terms, nOnAnag > 0 and string.format(", +%d for terms on anagathics", nOnAnag) or ""),
		string.format("Roll for ageing (2D, DM %s)", fmtDM(nDM)), { dice = "2d6", mod = nDM, desc = "Ageing" }, function(nTotal)
			local nRow = math.max(-6, math.min(1, nTotal));
			local e = TCData.AGEING[nRow];
			log(string.format("Ageing %d: %s", nTotal, e.text));
			applyAgeing(e, fnNext);
		end);
end

function applyAgeing(e, fnNext)
	local tLeft = {};
	for _, n in ipairs(e.phys or {}) do table.insert(tLeft, n); end
	local tUsed = {};
	local function nextPhys()
		if #tLeft == 0 then
			if e.ment then
				local tOpts = {};
				for _, s in ipairs(TCData.MENTAL) do
					table.insert(tOpts, { label = string.format("%s %d to %d (-%d)", statShort(s), getStat(s), math.max(0, getStat(s) - e.ment), e.ment), fn = function() changeStat(s, -e.ment); checkCrisis(fnNext); end });
				end
				return setTask({ title = "Ageing", text = e.text .. "\n\nChoose the mental characteristic.", options = tOpts });
			end
			return checkCrisis(fnNext);
		end
		local n = table.remove(tLeft, 1);
		local tOpts = {};
		for _, s in ipairs(TCData.PHYSICAL) do
			if not tUsed[s] then
				table.insert(tOpts, { label = string.format("%s %d to %d (-%d)", statShort(s), getStat(s), math.max(0, getStat(s) - n), n), fn = function() tUsed[s] = true; changeStat(s, -n); nextPhys(); end });
			end
		end
		setTask({ title = "Ageing", text = e.text .. "\n\nYou choose which characteristics are affected.", options = tOpts });
	end
	nextPhys();
end

function checkCrisis(fnNext, bPhysicalOnly)
	local tZero = {};
	for _, s in ipairs(bPhysicalOnly and TCData.PHYSICAL or TCData.STATS) do
		if getStat(s) <= 0 then table.insert(tZero, s); end
	end
	if #tZero == 0 then return fnNext(); end
	rollStep("Ageing crisis", "A characteristic has fallen to 0. You die unless you pay 1D x Cr10,000 for medical care, which brings it back to 1. From now on you automatically fail any Qualification roll.",
		"Roll the medical bill (1D x Cr10,000)", { dice = "1d6", desc = "Ageing crisis care", mult = 10000 }, function(n)
			addDebt(n * 10000, "ageing crisis care");
			for _, s in ipairs(tZero) do changeStat(s, 1 - getStat(s)); end
			S.crisis = true;
			fnNext();
		end);
end

function getAnagathicsOptions(fnBack)
	local t = {};
	local v = curVisit();
	if v and TCData.CAREERS[v.key].prison then return t; end
	if S.anag.on then
		table.insert(t, { label = "Stop taking anagathics (roll on the Ageing Table at once)", fn = function()
			S.anag.on = false;
			log("You stop taking anagathics.");
			local nDM = -#S.terms;
			rollStep("Ageing", "Stopping anagathics: roll on the Ageing Table at once.", string.format("Roll for ageing (2D, DM %s)", fmtDM(nDM)), { dice = "2d6", mod = nDM, desc = "Ageing (stopped anagathics)" }, function(nTotal)
				local e = TCData.AGEING[math.max(-6, math.min(1, nTotal))];
				log("Ageing: " .. e.text);
				applyAgeing(e, fnBack);
			end);
		end });
	elseif #S.terms >= 1 and S.anag.triedTerm ~= #S.terms then
		table.insert(t, rollOpt("Seek anagathics before this term (SOC 10+; a 2 means prison)", { dice = "2d6", mod = getStatDM("soc"), target = 10, desc = "Anagathics (SOC)" }, function(nTotal, nNatural)
			S.anag.triedTerm = #S.terms;
			if nNatural == 2 then
				log("Caught seeking anagathics: you go straight to the Prisoner career this term.");
				if curVisit() then
					return musterOut(curVisit(), function() S.cur = nil; S.forced = "prisoner"; S.term = nil; beginTerm(); end);
				end
				S.forced = "prisoner";
				S.term = nil;
				return beginTerm();
			end
			if nTotal >= 10 then
				S.anag.on = true;
				log("You find a supply of anagathics: you stop ageing, but must make two Survival rolls each term and pay 1D x Cr" .. R().anagathicsCost .. " a term.");
			else
				log("You find no supply of anagathics.");
			end
			fnBack();
		end, "While on anagathics you effectively do not age, but make two Survival rolls a term and pay 1D x Cr" .. R().anagathicsCost .. " a term out of your cash benefits."));
	end
	return t;
end

function endTermDecision(v, bMishap)
	local c = TCData.CAREERS[v.key];
	local function leave(bFinish)
		musterOut(v, function()
			S.lastLeft = { key = v.key, term = #S.terms };
			S.cur = nil;
			if bFinish then return finishCareers(); end
			beginTerm();
		end);
	end
	if c.prison then
		if v.released then
			log("Your sentence ends: you leave prison.");
			return leave(false);
		end
		S.forced = "prisoner";
		S.cur = nil;
		return musterOutPrisonLater(v);
	end
	local sWhy;
	if bMishap and v.ejected then sWhy = "The mishap ends your career."; end
	if v.mustLeave then sWhy = "Your Advancement roll means you must leave."; end
	if v.noreenlist then sWhy = "You may not re-enlist."; end
	if S.forced then sWhy = "Events take you elsewhere next term."; end
	if sWhy and (not v.mustStay or S.forced) then
		log(sWhy);
		return setTask({ title = "Leaving the " .. c.name .. " career", text = sWhy, options = {
			{ label = "Muster out and choose what comes next", fn = function() leave(false); end },
			{ label = "Muster out and stop here (begin your adventures)", fn = function() leave(true); end, disabled = S.forced ~= nil },
		} });
	end
	v.mustLeave = false;
	local tOpts = {};
	table.insert(tOpts, { label = string.format("Continue as %s (%s), term %d there", c.name, getAssignment(v).name, v.terms + 1), fn = function() v.mustStay = false; beginTerm(); end });
	if not v.mustStay then
		for _, a in ipairs(c.assignments) do
			if a.key ~= v.assignment and c.changeassign ~= "free" then
				table.insert(tOpts, { label = "Change assignment to " .. a.name .. (c.changeassign == "qual" and " (Qualification roll; keep your rank)" or " (a new career: muster out first)"),
					tip = a.text, fn = function() changeAssignment(v, a); end });
			end
		end
		table.insert(tOpts, { label = "Leave the " .. c.name .. " career, muster out and try something else", fn = function() leave(false); end });
		table.insert(tOpts, { label = "Leave the " .. c.name .. " career, muster out and stop here", fn = function() leave(true); end });
	end
	for _, o in ipairs(getAnagathicsOptions(function() endTermDecision(v, false); end)) do table.insert(tOpts, o); end
	local sState = string.format("You are %d, after %d term(s) in the %s career at rank %s%d%s.", getAge(), v.terms, c.name, v.officer and "O" or "", v.officer and v.orank or v.rank, getRankTitle(v) ~= "" and (" (" .. getRankTitle(v) .. ")") or "");
	if v.mustStay then sState = sState .. "\n\nYou rolled a natural 12 for Advancement: you must continue."; end
	setTask({ title = "End of term " .. #S.terms, text = sState, options = tOpts });
end

-- A prisoner stays inside: the career continues next term (forced).
function musterOutPrisonLater(v)
	S.cur = S.visits[#S.visits] == v and #S.visits or S.cur;
	for i, v0 in ipairs(S.visits) do if v0 == v then S.cur = i; end end
	S.forced = nil;
	local tOpts = { { label = "Serve another term", fn = function() beginTerm(); end } };
	-- Release needs an Advancement roll above the threshold: 2D (12 at best) plus the DM.
	local a = getAssignment(v);
	local nBest = 12 + getStatDM(a.adv[1]);
	local sText = string.format("You remain inside. Your Parole Threshold is %d.", v.parole or 0);
	if (v.parole or 0) >= nBest then
		sText = sText .. string.format("\n\nYour best possible Advancement roll (%d) cannot beat it, so by the book you would never leave. The book does not cover this: the referee may release you.", nBest);
		table.insert(tOpts, { label = "The referee releases you (muster out)", fn = function()
			note("Released from prison by the referee (the Parole Threshold could not be beaten).");
			musterOut(v, function() S.lastLeft = { key = v.key, term = #S.terms }; S.cur = nil; beginTerm(); end);
		end });
	end
	setTask({ title = "Still in prison", text = sText, options = tOpts });
end

function changeAssignment(v, a)
	local c = TCData.CAREERS[v.key];
	if c.changeassign == "newcareer" then
		return musterOut(v, function()
			S.cur = nil;
			S.term = { n = #S.terms + 1, lines = {}, skills = {} };
			log(string.format("=== Term %d (age %d) ===", #S.terms + 1, getAge()));
			local sStat, nTarget, nDM = getQualification(v.key);
			rollStep("New assignment: " .. a.name, "A new assignment in this career counts as a new career: a Qualification roll, starting again at rank 0.",
				string.format("Roll to qualify (%s %d+, DM %s)", statShort(sStat), nTarget, fmtDM(nDM)), { dice = "2d6", mod = nDM, target = nTarget, desc = c.name .. " Qualification (" .. a.name .. ")" }, function(nTotal)
					S.mods.qdm = 0;
					if nTotal >= nTarget then
						log("You qualify for " .. a.name .. ".");
						return enterCareer(v.key, a.key);
					end
					log("You fail to qualify for " .. a.name .. ".");
					failQual(v.key);
				end);
		end);
	end
	S.term = { n = #S.terms + 1, lines = {}, skills = {} };
	log(string.format("=== Term %d (age %d) ===", #S.terms + 1, getAge()));
	if isAutoQual(v.key) then
		v.assignment = a.key;
		log("You move to the " .. a.name .. " assignment.");
		return continueCareer(v);
	end
	local sStat, nTarget, nDM = getQualification(v.key);
	rollStep("Change assignment: " .. a.name, "Roll to qualify for the new assignment. On a failure you carry on in your old assignment without penalty; on a success you keep your rank.",
		string.format("Roll to qualify (%s %d+, DM %s)", statShort(sStat), nTarget, fmtDM(nDM)), { dice = "2d6", mod = nDM, target = nTarget, desc = c.name .. " Qualification (" .. a.name .. ")" }, function(nTotal)
			S.mods.qdm = 0;
			if nTotal >= nTarget then
				v.assignment = a.key;
				log("You move to the " .. a.name .. " assignment.");
			else
				log("You stay in your old assignment.");
			end
			continueCareer(v);
		end);
end

function finishCareers()
	local v = curVisit();
	if v and not v.musteredOut then
		return musterOut(v, function() S.cur = nil; finishCareers(); end);
	end
	S.done = true;
	S.task = nil;
	log(string.format("=== Ready for adventure at age %d ===", getAge()));
	refresh();
end

--
-- Background skills
--

function getBackgroundCounts()
	local n = 0;
	for _ in pairs(S.bg) do n = n + 1; end
	-- Learned before age 18: the allowance uses EDU as it was then.
	return n, math.max(0, TCData.getDM(S.bgEDU or getStat("edu")) + 3);
end

function toggleBackground(sSkill, bOn)
	if S.started then return; end
	if bOn then
		local nChosen, nAllowed = getBackgroundCounts();
		if nChosen >= nAllowed then refresh(); return; end
		S.bg[sSkill] = true;
	else
		S.bg[sSkill] = nil;
	end
	refresh();
end

-- Background skills go onto the skill list when the first term begins.
function applyBackground()
	if S.bgApplied then return; end
	S.bgApplied = true;
	S.bgEDU = getStat("edu");
	for sSkill in pairs(S.bg) do
		if S.skills[sSkill] == nil then S.skills[sSkill] = 0; end
	end
end

--
-- Benefits page: items, medical care
--

function parseCost(s)
	s = trim(s):gsub(",", "");
	local nM = tonumber(s:match("^MCr%s*([%d%.]+)"));
	if nM then return nM * 1000000; end
	local n = tonumber(s:match("^Cr%s*([%d%.]+)"));
	if n then return n; end
	return tonumber(s) or 0;
end

local function itemMatches(node, sType)
	local sT = DB.getValue(node, "type", "");
	local sSub = DB.getValue(node, "subtype", "");
	local sSkill = DB.getValue(node, "skill", ""):lower();
	if sType == "armour" then return sT == "Armour"; end
	if sType == "implant" then return sT == "Augments"; end
	if sType == "blade" then return sT == "Weapons" and sSkill:find("blade", 1, true) ~= nil; end
	if sType == "gun" then return sT == "Weapons" and (sSub:find("Slug", 1, true) or sSub:find("Energy", 1, true)) ~= nil; end
	if sType == "weapon" then return sT == "Weapons" and not sSub:find("Spacecraft", 1, true) and not sT:find("Spacecraft", 1, true); end
	if sType == "science" then return sT ~= "Weapons" and sT ~= "Armour" and sT ~= "Augments" and not sT:find("Spacecraft", 1, true) and sT ~= ""; end
	return false;
end

function getBenefitItems(b)
	local t, tSeen = {}, {};
	local d = b.def or TCData.BENEFITS[b.name];
	for _, node in ipairs(DB.getChildrenGlobal("reference.equipmentdata")) do
		local sName = DB.getValue(node, "name", "");
		if sName ~= "" and not tSeen[sName] and itemMatches(node, d.itemtype)
				and parseCost(DB.getValue(node, "cost", "")) <= d.limit and DB.getValue(node, "tl", 0) <= d.tl then
			tSeen[sName] = true;
			table.insert(t, node);
		end
	end
	for _, node in ipairs(DB.getChildrenGlobal("item")) do
		local sName = DB.getValue(node, "name", "");
		if sName ~= "" and not tSeen[sName] and itemMatches(node, d.itemtype)
				and parseCost(DB.getValue(node, "cost", "")) <= d.limit and DB.getValue(node, "tl", 0) <= d.tl then
			tSeen[sName] = true;
			table.insert(t, node);
		end
	end
	table.sort(t, function(a, c) return DB.getValue(a, "name", "") < DB.getValue(c, "name", ""); end);
	return t;
end

function chooseBenefitItem(nIndex, sPath)
	local b = S.benefits[nIndex];
	if not b then return; end
	b.item = sPath;
	b.itemname = sPath and DB.getValue(DB.findNode(sPath), "name", "") or nil;
	-- Not refresh(): rebuilding the list would destroy the combobox while its onSelect runs.
	updateTabs();
end

function rollMedical(nIndex)
	local inj = S.injuries[nIndex];
	if not inj or inj.cover then return; end
	local v = inj.visit and S.visits[inj.visit];
	local sKind = v and TCData.CAREERS[v.key].medical or "rough";
	roll({ dice = "2d6", mod = inj.rank or 0, desc = "Medical bills (2D + rank)" }, function(nTotal)
		local nPct = 0;
		for _, r in ipairs(TCData.MEDICAL[sKind]) do
			if nTotal >= r[1] then nPct = r[2]; end
		end
		inj.cover = nPct;
		inj.cost = math.floor(inj.points * TCData.MEDICAL_COST_PER_POINT * (100 - nPct) / 100);
		log(string.format("Medical care: your employer pays %d%%; restoring %s costs you Cr%d.", nPct, statShort(inj.stat), inj.cost));
	end);
end

function settleMedical(nIndex, bRestore)
	local inj = S.injuries[nIndex];
	if not inj or inj.settled then return; end
	inj.settled = true;
	if bRestore then
		inj.restored = true;
		S.delta[inj.stat] = (S.delta[inj.stat] or 0) + inj.points;
		if (inj.cost or 0) > 0 then addDebt(inj.cost, "medical care (" .. statShort(inj.stat) .. ")"); end
		log(string.format("%s restored by %d.", statShort(inj.stat), inj.points));
	else
		log(string.format("You live with the injury (%s -%d).", statShort(inj.stat), inj.points));
	end
	refresh();
end

function getDebtTotal()
	local n = 0;
	for _, d in ipairs(S.debts) do n = n + d.amount; end
	return n;
end

-- Cash after paying medical care and anagathics out of benefits.
function getFinalCash()
	return S.cash - getDebtTotal();
end

--
-- Skills page: connections, skill package, warnings
--

function getSkillWarnings()
	local t = {};
	if getTotalSkillLevels() > getSkillLimit() then
		table.insert(t, string.format("Total skill levels %d pass 3 x (INT + EDU) = %d", getTotalSkillLevels(), getSkillLimit()));
	end
	return t;
end

function setConnection(nSlot, sKey, sValue)
	S.connections[nSlot] = S.connections[nSlot] or {};
	S.connections[nSlot][sKey] = sValue;
end

-- Connections rule: an extra skill per linked Traveller (two at most, not
-- Jack-of-all-Trades, never above 3).
function applyConnection(nSlot, sSkill)
	local c = S.connections[nSlot] or {};
	if c.applied or not S.done then return; end
	if sSkill == "Jack-of-all-Trades" then return; end
	local function done()
		c.applied = true;
		c.skill = S.lastConnection or sSkill;
		S.connections[nSlot] = c;
		refresh();
	end
	local nCur = getSkillLevel(sSkill);
	if nCur and nCur >= 3 and not hasSpecialties(sSkill) then
		log(sSkill .. " is already 3: the Connections rule cannot raise it.");
		return;
	end
	-- The Connections rule may not take the skill it raises above 3; other
	-- specialties keep whatever they already had.
	local tBefore = {};
	for k, n in pairs(S.skills) do tBefore[k] = n; end
	gainSkill(sSkill, nil, { title = "Connection" }, function()
		local sRaised, bRefused = nil, false;
		for k, n in pairs(S.skills) do
			if tBefore[k] ~= n and n > 0 then
				if n > 3 then
					S.skills[k] = tBefore[k];
					log(string.format("%s would go to %d: the Connections rule cannot raise a skill above 3. Choose another.", k, n));
					bRefused = true;
				else
					sRaised = k;
				end
			end
		end
		S.task = nil;
		if not bRefused and not sRaised then
			log("That gives no new level: the Connection is not used. Choose another skill or specialty.");
		end
		if bRefused or not sRaised then return refresh(); end
		S.lastConnection = sRaised;
		done();
	end);
end

function setPackage(sName)
	S.package = sName or "";
	S.packagePicks = {};
	refresh();
end

function getPackage()
	for _, p in ipairs(TCData.SKILL_PACKAGES) do
		if p.name == S.package then return p; end
	end
	return nil;
end

function togglePackageSkill(nIndex, bOn)
	local p = getPackage();
	if not p or S.packagePicks[nIndex] == "applied" then return; end
	S.packagePicks[nIndex] = bOn and true or nil;
end

-- Applies the ticked package skills (as "Skill 1": no benefit if already 1+).
function applyPackage()
	local p = getPackage();
	if not p then return; end
	local tIdx = {};
	for i, v in pairs(S.packagePicks) do
		if v == true then table.insert(tIdx, i); end
	end
	table.sort(tIdx);
	local k = 0;
	local function step()
		k = k + 1;
		if k > #tIdx then S.task = nil; refresh(); return; end
		S.packagePicks[tIdx[k]] = "applied";
		runFx(parseSpec(p.skills[tIdx[k]]), { title = "Skill package" }, step);
	end
	step();
end

--
-- Summary helpers
--

function getUPP()
	local t = {};
	for _, s in ipairs(TCData.STATS) do
		local n = getStat(s);
		table.insert(t, (n < 10) and tostring(n) or string.char(55 + math.min(n, 35)));
	end
	return table.concat(t);
end

function getSkillListText()
	local t = {};
	for k, n in pairs(S.skills) do table.insert(t, { k, n }); end
	for k, n in pairs(S.talents) do table.insert(t, { k .. " (psionic)", n }); end
	table.sort(t, function(a, b) return a[1] < b[1]; end);
	local tOut = {};
	for _, x in ipairs(t) do table.insert(tOut, x[1] .. " " .. x[2]); end
	return table.concat(tOut, ", ");
end

function getCareerSummary()
	local t = {};
	for _, v in ipairs(S.visits) do
		local c = TCData.CAREERS[v.key];
		table.insert(t, string.format("%s (%s): %d term(s), rank %s%d%s", c.name, getAssignment(v).name, v.terms, v.officer and "O" or "", v.officer and v.orank or v.rank, getRankTitle(v) ~= "" and (" " .. getRankTitle(v)) or ""));
	end
	return table.concat(t, "\n");
end

function getBenefitsText()
	local t = {};
	for _, b in ipairs(S.benefits) do
		if b.kind == "item" then
			table.insert(t, b.name .. ": " .. (b.itemname or "(not chosen)"));
		elseif b.kind == "ship" then
			table.insert(t, b.ship .. (b.mortgage and string.format(" (%d%% of the mortgage paid)", b.paid) or ""));
		else
			table.insert(t, b.name);
		end
	end
	if S.shares > 0 then table.insert(t, S.shares .. " Ship Share" .. (S.shares == 1 and "" or "s")); end
	if S.pension > 0 then table.insert(t, string.format("Pension Cr%d a year", S.pension)); end
	return table.concat(t, "\n");
end

--
-- Create the character
--

function createCharacter()
	if _creationPending then return; end
	if trim(S.name) == "" then S.name = "Unnamed Traveller"; end
	if Session.IsHost then
		local nodeChar = DB.createChild("charsheet");
		DB.setValue(nodeChar, "name", "string", trim(S.name));
		RecordManager.onRecordAddEvent("charsheet", nodeChar);
		buildCharacter(nodeChar);
	else
		_creationPending = true;
		local tBuild = UtilityManager.copyDeep(S);
		UserManager.requestIdentity(nil, { fnResponse = function(result, identity)
			_creationPending = false;
			if not identity then return; end
			local nodeChar = DB.findNode(DB.getPath("charsheet", identity));
			if nodeChar then
				S = tBuild;
				buildCharacter(nodeChar);
			end
		end });
	end
end

local LONG = { str = "strength", dex = "dexterity", ["end"] = "endurance", int = "intelligence", edu = "education", soc = "social", psi = "psi" };

local function findSkillRecord(sName)
	local sLower = sName:lower();
	for _, node in ipairs(DB.getChildrenGlobal("reference.skilldata")) do
		local sN = canonical(DB.getValue(node, "name", "")):lower();
		if sN == sLower then return node; end
	end
	return nil;
end

function buildCharacter(nodeChar)
	DB.setValue(nodeChar, "name", "string", trim(S.name));
	-- Characteristics: the score, its DM, and the current (wound track) value.
	local tStats = { "str", "dex", "end", "int", "edu", "soc" };
	if S.psi then table.insert(tStats, "psi"); end
	for _, s in ipairs(tStats) do
		local n = getStat(s);
		local nDM = TCData.getDM(n);
		DB.setValue(nodeChar, "attributes." .. LONG[s], "number", n);
		DB.setValue(nodeChar, "attributes." .. s .. "_mod", "number", nDM);
		DB.setValue(nodeChar, "woundtrack." .. s, "number", n);
		DB.setValue(nodeChar, "woundtrack." .. s .. "_mod", "number", nDM);
	end
	-- Species: name, link, traits (and the natural weapons the ruleset makes for them).
	local nodeSpecies = getSpeciesNode();
	if nodeSpecies then
		DB.setValue(nodeChar, "race", "string", DB.getValue(nodeSpecies, "name", ""));
		DB.setValue(nodeChar, "racelink", "windowreference", "reference_race", DB.getPath(nodeSpecies));
		local nodeTraits = DB.createChild(nodeChar, "racialtraitslist");
		for _, vTrait in ipairs(DB.getChildList(nodeSpecies, "traits")) do
			local sTrait = DB.getValue(vTrait, "name", "");
			local sDesc = DB.getValue(vTrait, "description", "");
			local nodeT = DB.createChild(nodeTraits);
			DB.setValue(nodeT, "name", "string", sTrait);
			DB.setValue(nodeT, "details", "string", sDesc);
			if CharManager.specialActionForTrait then
				CharManager.specialActionForTrait(nodeChar, sTrait, sDesc);
			end
		end
	end
	-- Skills, each with the book's text.
	local nodeSkills = DB.createChild(nodeChar, "skilllist");
	local tNames = {};
	for k in pairs(S.skills) do table.insert(tNames, k); end
	table.sort(tNames);
	for _, sSkill in ipairs(tNames) do
		local nodeS = DB.createChild(nodeSkills);
		local nodeRec = findSkillRecord(sSkill);
		DB.setValue(nodeS, "name", "string", (nodeRec and DB.getValue(nodeRec, "name", "")) or sSkill);
		DB.setValue(nodeS, "level", "number", S.skills[sSkill]);
		DB.setValue(nodeS, "noedit", "number", 1);
		DB.setValue(nodeS, "locked", "number", 1);
		DB.setValue(nodeS, "speciality", "number", nodeRec and DB.getValue(nodeRec, "speciality", 0) or 0);
		if nodeRec then DB.setValue(nodeS, "text", "formattedtext", DB.getValue(nodeRec, "text", "")); end
		if CharManager.checkSkillHasMiscActions then
			CharManager.checkSkillHasMiscActions(nodeChar, sSkill, S.skills[sSkill]);
		end
	end
	-- Psionic talents, through the ruleset (it adds each talent's powers from the book).
	if next(S.talents) then
		local nodeData = nil;
		for _, node in ipairs(DB.getChildrenGlobal("reference.psionicdata")) do
			nodeData = DB.getParent(node);
			break;
		end
		for sTalent, n in pairs(S.talents) do
			local nodeE = nil;
			if nodeData and CharManager.addPsionicDB then
				nodeE = CharManager.addPsionicDB(nodeChar, sTalent, nodeData);
			end
			if not nodeE then
				nodeE = DB.createChild(DB.createChild(nodeChar, "psitalentlist"));
				DB.setValue(nodeE, "name", "string", sTalent);
				DB.setValue(nodeE, "noedit", "number", 1);
				DB.setValue(nodeE, "locked", "number", 1);
			end
			DB.setValue(nodeE, "level", "number", n);
		end
		if not OptionsManager.isOption("CHARPSI", "yes") then
			ChatManager.SystemMessage("Psionic talents added. Turn on Options > Use PSI Characteristic to see them on the character sheet.");
		end
	end
	-- Career history: education first, then one row per career.
	local nodeHist = DB.createChild(nodeChar, "careerhistorylist");
	if S.education and S.education.done then
		local nodeH = DB.createChild(nodeHist);
		DB.setValue(nodeH, "careerhistorytype", "number", 0);
		DB.setValue(nodeH, "branch", "string", S.education.kind == "university" and "University" or TCData.ACADEMIES[S.education.branch].name);
		DB.setValue(nodeH, "career", "string", S.education.grad and (S.education.honours and "Graduated with honours" or "Graduated") or "Did not graduate");
		DB.setValue(nodeH, "events", "string", "1 term");
	end
	for _, v in ipairs(S.visits) do
		local c = TCData.CAREERS[v.key];
		local nodeH = DB.createChild(nodeHist);
		DB.setValue(nodeH, "careerhistorytype", "number", 0);
		DB.setValue(nodeH, "branch", "string", c.name);
		DB.setValue(nodeH, "career", "string", getAssignment(v).name);
		DB.setValue(nodeH, "rank", "string", (v.officer and "O" or "") .. tostring(v.officer and v.orank or v.rank));
		DB.setValue(nodeH, "title", "string", getRankTitle(v));
		DB.setValue(nodeH, "events", "string", string.format("%d term%s", v.terms, v.terms == 1 and "" or "s"));
	end
	-- Details.
	DB.setValue(nodeChar, "age", "string", tostring(getAge()));
	DB.setValue(nodeChar, "gender", "string", trim(S.gender));
	DB.setValue(nodeChar, "homeworld", "string", trim(S.homeworld));
	DB.setValue(nodeChar, "allies", "string", getAssocText());
	DB.setValue(nodeChar, "cashonhand", "string", tostring(getFinalCash()));
	local tBack = {};
	if trim(S.appearance) ~= "" then table.insert(tBack, trim(S.appearance)); end
	if trim(S.why) ~= "" then table.insert(tBack, "Why travelling: " .. trim(S.why)); end
	table.insert(tBack, "UPP " .. getUPP() .. ". " .. getCareerSummary():gsub("\n", ". "));
	DB.setValue(nodeChar, "background", "string", table.concat(tBack, "\n"));
	local tNotes = {};
	local sBen = getBenefitsText();
	if sBen ~= "" then table.insert(tNotes, "BENEFITS\n" .. sBen); end
	if #S.debts > 0 then
		local tD = {};
		for _, d in ipairs(S.debts) do table.insert(tD, string.format("Cr%d %s", d.amount, d.what)); end
		table.insert(tNotes, "PAID OUT OF CASH\n" .. table.concat(tD, "\n") .. (getFinalCash() < 0 and string.format("\nDebt at the start of play: Cr%d", -getFinalCash()) or ""));
	end
	if #S.notes > 0 then table.insert(tNotes, "FOR THE REFEREE\n" .. table.concat(S.notes, "\n")); end
	table.insert(tNotes, "CREATION LOG\n" .. getLogText());
	DB.setValue(nodeChar, "notes", "string", table.concat(tNotes, "\n\n"));
	-- Gear chosen from the benefits.
	for _, b in ipairs(S.benefits) do
		if b.kind == "item" and b.item then
			local nodeItem = ItemManager.addItemToList(DB.getPath(nodeChar, "inventorylist"), "item", b.item);
			-- The Traveller knows what their own gear is.
			if type(nodeItem) == "databasenode" then
				DB.setValue(nodeItem, "isidentified", "number", 1);
			end
		end
	end
	ChatManager.SystemMessage(string.format("Traveller created: %s (%s, age %d).", trim(S.name), getUPP(), getAge()));
	Interface.openWindow("charsheet", nodeChar);
	-- Done: the next wizard starts a new Traveller.
	reset();
	if _w then _w.close(); end
end
