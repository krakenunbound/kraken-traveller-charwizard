# Install & User Guide

## Install

1. Download **`KrakenTravellerCharWizard.ext`** from the [latest release](../../releases/latest).
2. Copy it into the **`extensions`** folder of your Fantasy Grounds data folder (FGU launcher → Settings → Data Folder; on Windows usually `%APPDATA%\SmiteWorks\Fantasy Grounds\extensions`). Don't unzip it.
3. Start FGU, select your **Mongoose Traveller (2E)** campaign, tick **Traveller Character Creation Wizard** in the campaign's extension list, and start the campaign.
4. Load the **MGT2 Core Rulebook** (or the **MGT2 Players Reference**) in **Library → Modules**.

To update, replace the `.ext` with the new one and restart the campaign.

## Walkthrough

Open **Characters** and click the **starship icon**.

![Launch](docs/images/01-launch.png)

Every page has collapsible **Instructions** at the top. The tabs carry a **!** while a step still needs something and a check when it's done.

### 1. Characteristics

Press **Roll characteristics**: 2D six times, each roll in chat, placed STR to SOC. Drag a rolled score onto another to swap them (the book lets you assign the rolls in any order). Each characteristic shows its Dice Modifier and the UPP.

![Characteristics](docs/images/02-characteristics.png)

### 2. Species

Choose **Human**, **Aslan** or **Vargr** (any species record in your loaded books). Alien modifiers apply on top of the rolls (a score may pass 15 but never drops below 1); the traits are listed and go onto the sheet. You can change your mind until your first career term starts.

![Species list](docs/images/03-species-list.png)

![Species](docs/images/04-species.png)

### 3. Background

Tick your background skills: as many as your Education DM + 3, at level 0 (EDU as it was at 18). Optionally name your homeworld.

![Background](docs/images/05-background.png)

### 4. Careers

The heart of the wizard. A card shows the current step, the book's text and buttons. Each roll button says what it needs (for example **Roll Survival (END 6+, DM -1)**); rolls go to chat and the wizard carries on from the result. Everything that happens is written under **Life so far** and goes into the sheet's notes.

**Choose a career** (or University or a military academy in terms 1-3). The buttons show the qualification target and your DM with all modifiers; a career you left last term is greyed out.

![Careers](docs/images/06-careers.png)

![Qualification](docs/images/07-qualification.png)

If you fail, choose the **Draft** (once in your life) or the **Drifter** career. Then pick an **assignment**: each shows its Survival and Advancement rolls.

![Assignment](docs/images/08-assignment.png)

Each term: **basic training** (first career: every Service Skill at 0; later careers: one), a roll on a **Skills and Training** table of your choice, **Survival**, then an **Event** or, if Survival failed, a **Mishap**. Skills with specialties ask which specialty when they reach level 1.

![Skills and Training](docs/images/09-skills-training.png)

![Specialty](docs/images/10-specialty.png)

![Event](docs/images/11-event.png)

Military careers may try for a **commission**; every career rolls **Advancement** (success: next rank, the rank's bonus and an extra Skills roll; a roll no higher than your terms there means you must leave; a natural 12 means you must stay).

At the end of each term choose: **continue**, **change assignment**, or **leave and muster out** (and try something else, or stop and start adventuring). From the term after your first you can **seek anagathics** (SOC 10+).

![End of term](docs/images/12-end-of-term.png)

From the end of your fourth term you roll for **ageing** each term.

![Ageing](docs/images/12b-ageing.png)

**Mustering out**: one Benefit roll per full term, more for high rank. For each, roll **Cash** (three times in your whole life) or **Benefits**; the card lists both columns, and the DMs you earned in events can be spent on the roll you choose.

![Mustering out](docs/images/13-mustering-out.png)

### 5. Benefits

Pick each gear benefit from the loaded books (weapons, armour, combat implants, scientific equipment) within its cost and Tech Level limit. For each injury from your careers, roll for your former employer's cover (2D + your rank there), then **Pay and restore** (Cr5000 a point, the rest paid out of your cash) or **Live with it**. Cash, ship shares, ships and pension are summed up here.

![Benefits](docs/images/14-benefits.png)

### 6. Skills

Your final skills and total levels. Use the **Connections rule** (an event that involved another player's Traveller gives you both a free skill; two at most, not Jack-of-all-Trades, never above 3) and tick the skills you took from your group's **Skill Package**.

![Skills](docs/images/15-skills.png)

### 7. Finish

Enter the name, gender, homeworld, appearance and why your Traveller is travelling. Anything still open is listed (nothing stops you; open items go into the notes). Press **Create Character**.

![Finish](docs/images/16-finish.png)

## The finished character

The sheet opens with everything filled in. Give your Traveller a portrait the usual way (click the portrait frame).

![Portrait](docs/images/17-portrait.png)

![Main](docs/images/18-sheet-main.png)

![Skills](docs/images/19-sheet-skills.png)

![Equipment](docs/images/20-sheet-equipment.png)

![Actions](docs/images/22-sheet-actions.png)

![Career history](docs/images/21-sheet-personal.png)

## Options

**Options → Traveller Wizard → Players may reroll characteristics** (off by default; the GM can always reroll).

Psionic talents show on the sheet when the ruleset option **Use PSI Characteristic** is on.

## Rulings where the book is silent

- A prisoner whose Parole Threshold can no longer be beaten (12 against a low DM) may be released by the referee.
- Prison event 9 (the lawyer): the lawyer's roll is compared with the Parole Threshold.
- A physical characteristic reduced to 0 by injury uses the ageing crisis rule (1D x Cr10,000 for care, back to 1).
- Agent event 8 failed: the Rogue or Citizen mishap applies but does not eject you from the Agent career.
- The university DM for Citizen (corporate) and Entertainer (journalist): if the DM was what got you in, you take that assignment.
- The 3 x (INT + EDU) skill limit applies when a skill is gained; if ageing lowers INT or EDU later, the Skills page warns instead of removing skills.
- Prisoners may not use anagathics: going to prison stops them, with the immediate Ageing roll the book requires.

## Reporting problems

Open an issue with what you did, what happened, and the end of FGU's console log (`console.log` in your data folder) if there was an error.
