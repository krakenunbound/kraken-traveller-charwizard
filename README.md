# Kraken Traveller Character Wizard

A guided character-creation wizard for **Mongoose Traveller 2nd Edition** on SmiteWorks' **Mongoose Traveller (2E) ruleset (MGT2)** in **Fantasy Grounds Unity**.

Traveller creation is a mini-game of its own: you start at 18 and live out your past four years at a time, qualifying for careers, surviving (or not), meeting events and mishaps, earning commissions and promotions, ageing, and finally mustering out with cash, gear and a few friends and enemies. This wizard walks a player through every one of those decisions, follows the Core Rulebook's tables, shows what each roll needs before you roll it, and writes the finished Traveller onto the character sheet.

Tabbed flow: **Characteristics → Species → Background → Careers → Benefits → Skills → Finish.**

> 📰 **What's new:** see the [Changelog](CHANGELOG.md).
>
> 📖 **New here? Read the [Install & User Guide](GUIDE.md)** for installing, the walkthrough of every tab and the rulings the wizard makes where the book is silent.

## Screenshots

**Roll 2D six times (every roll in chat) and drag the scores into place**

![Characteristics](docs/images/02-characteristics.png)

**Careers one term at a time: every button says what the roll needs and your DM**

![Choose a career](docs/images/06-careers.png)

**Events and mishaps straight from the book, with their choices and checks as buttons**

![An event](docs/images/11-event.png)

**Muster out with Cash and Benefit rolls, gear picked from your loaded books**

![Mustering out](docs/images/13-mustering-out.png)

![Benefits](docs/images/14-benefits.png)

**…and the finished Traveller on the MGT2 sheet**

![Character sheet](docs/images/18-sheet-main.png)

## What it does for you

- **The whole Core Rulebook creation sequence.** University and the Army/Marine/Navy academies (terms 1-3), qualification with every DM shown (previous careers, age, events, graduation), the Draft (once in a life) and the Drifter career, basic training, the Skills and Training tables, Survival (a natural 2 always fails), events, mishaps, life events and unusual events, commissions, advancement (must-leave and must-stay results), rank titles and bonuses, ageing from the fourth term, ageing crises, anagathics, injuries and medical care, prison and parole, psionic testing and the Psion career with talent learning rolls.
- **All 14 careers** with their three assignments each: Agent, Army, Citizen, Drifter, Entertainer, Marine, Merchant, Navy, Noble, Rogue, Scholar, Scout, Psion and Prisoner.
- **Rolls in the open.** Every roll uses FGU dice and goes to chat with its target and DM.
- **Rules kept for you.** Skills cap at 4 during creation, total skill levels at 3 x (INT + EDU), characteristics at 15 (SOC overflow becomes Ship Shares), cash rolls at three per life, no return to a career the term after leaving it, specialties chosen when a skill reaches level 1.
- **Mustering out done properly.** Benefit rolls per term, rank bonus rolls and DM, event DMs you choose when to spend, Gambler DM on cash, pensions, TAS Membership, ship shares, ships with mortgages, and gear benefits (weapons, armour, implants, scientific equipment) chosen from the item records of your loaded books within the benefit's Cr and Tech Level limit.
- **The table extras.** The Connections rule (two free skills) and the group's Skill Package.
- **A complete sheet.** Characteristics and DMs, species traits (Aslan dewclaw, Vargr bite), skills with the book's text, psionic talents with their powers, career history with ranks and titles, contacts/allies/rivals/enemies, cash, gear on the Equipment and Actions tabs, and the whole creation log in the notes for the referee.

## Requirements

- **Fantasy Grounds Unity**
- SmiteWorks' **Mongoose Traveller (2E)** ruleset (**MGT2**)
- The **MGT2 Core Rulebook** module (or the free **MGT2 Players Reference**) loaded in the campaign. Species, skills, psionic powers and gear are read from the loaded books; the career tables follow the Core Rulebook.

## Install

1. Download **`KrakenTravellerCharWizard.ext`** from the [latest release](../../releases/latest).
2. Put it in your Fantasy Grounds data folder's **`extensions`** folder (FGU Settings → Data Folder; on Windows usually `%APPDATA%\SmiteWorks\Fantasy Grounds\extensions`).
3. In the FGU launcher, select your MGT2 campaign and tick **Traveller Character Creation Wizard** in the extension list, then start the campaign.
4. Open **Characters** and click the **starship icon** at the top left of the window.

Players have the same icon on their Characters window; pressing Create Character asks FGU for a new character for that player (this beta was tested by the GM; please report how it goes for players).

## Notes

- Traveller creation is meant to be done as a group, term by term. The wizard keeps each player's build on their own machine until they press **Create Character**.
- Option: **Options → Traveller Wizard → Players may reroll characteristics** (off by default; the GM can always reroll).
- Psionic talents appear on the sheet when the ruleset option **Use PSI Characteristic** is on.

Made by The Kraken. Traveller is a trademark of Far Future Enterprises; Mongoose Traveller is published by Mongoose Publishing. This is a fan-made tool and needs your own copy of the books in Fantasy Grounds.
