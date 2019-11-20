class OPTC_CharactersRulers extends X2DownloadableContentInfo config(RulersRegen);

`define RR_Log(msg) `Log(`msg,, 'RulersRegen')
`define RR_Warn(msg) `Warn(`msg,, 'RulersRegen')

struct RegenRules
{
	var name RulerName;
	var float HealthRegen;
	var float ArmorRegen;
};

var config array<RegenRules> Rulers;
var config float REGEN_HEALTH;
var config float REGEN_ARMOR;
var config bool FAIR_SHARE;

static event OnPostTemplatesCreated()
{
	local X2CharacterTemplateManager CharacterMgr;
	local AlienRulerData RulerData ;

	local RegenRules Ruler;

	`RR_Log("Rulers Regen loaded");

	CharacterMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();

	// If all Rulers should apply the same regeneration factors, ignore individual configuration
	if(default.FAIR_SHARE)
	{
		// Loop through AlienRulerTemplates entries to recover Ruler's template name.
		// Mods should also add these entries since it links their TacticalTags.
		foreach class'XComGameState_AlienRulerManager'.default.AlienRulerTemplates(RulerData)
		{
			PatchCharacterTemplate(CharacterMgr, RulerData.AlienRulerTemplateName);
		}
	}
	else
	{
		foreach default.Rulers(Ruler)
		{
			PatchCharacterTemplate(CharacterMgr, Ruler.RulerName);
		}
	}
}

static function PatchCharacterTemplate(X2CharacterTemplateManager CharacterMgr, Name TemplateName)
{
	local array<X2DataTemplate> TemplateAllDifficulties;
	local X2DataTemplate Template;
	local X2CharacterTemplate CharacterTemplate;

	CharacterMgr.FindDataTemplateAllDifficulties(TemplateName, TemplateAllDifficulties);
		
	foreach TemplateAllDifficulties(Template)
	{
		CharacterTemplate = X2CharacterTemplate(Template);

		if (CharacterTemplate != none)
		{
			CharacterTemplate.OnStatAssignmentCompleteFn = RegenAlienRulerHealthAndArmor;
			`RR_Log(CharacterTemplate.DataName @ "patched");
		}
	}
}

// Called after Character is created
static function RegenAlienRulerHealthAndArmor(XComGameState_Unit UnitState)
{
	local XComGameStateHistory History;
	local XComGameState_AlienRulerManager RulerMgr;
	local XComGameState_Unit RulerState;
	local StateObjectReference RulerRef;
	local int Idx;

	History = `XCOMHISTORY;
	RulerMgr = XComGameState_AlienRulerManager(History.GetSingleGameStateObjectForClass(class'XComGameState_AlienRulerManager'));
	RulerRef = RulerMgr.GetAlienRulerReference(UnitState.GetMyTemplateName());

	if (RulerRef.ObjectID != 0 && RulerRef.ObjectID != UnitState.ObjectID)
	{
		// Check if Ruler was in game at point. If so apply the regeneration process
		RulerState = XComGameState_Unit(History.GetGameStateForObjectID(RulerRef.ObjectID));

		// If all Rulers should apply the same regeneration factors, ignore individual configuration
		if(default.FAIR_SHARE)
		{
			RegenHP(UnitState, RulerState, default.REGEN_HEALTH);
			RegenArmor(UnitState, RulerState, default.REGEN_ARMOR);
		}
		else
		{
			Idx = default.Rulers.Find('RulerName', UnitState.GetMyTemplateName());

			if (Idx != INDEX_NONE)
			{
				RegenHP(UnitState, RulerState, default.Rulers[Idx].HealthRegen);
				RegenArmor(UnitState, RulerState, default.Rulers[Idx].ArmorRegen);
			}		
			else
			{
				`RR_Warn(UnitState.GetMyTemplateName() @ "Ruler was not found in config.");
			}
		}

		// Once stats are set update when Ruler is supposed to flee
		// class'X2Helpers_DLC_Day60'.static.UpdateRulerEscapeHealth(UnitState);
		class'X2Helpers_DLC_Day60'.static.UpdateRulerEscapeHealth(RulerState);
		UnitState.bIsSpecial = RulerState.bIsSpecial;
	}
}

static function RegenHP(XComGameState_Unit UnitState, XComGameState_Unit RulerState, float ConfHealthRegen)
{
	local int MaxHP, CurrentHP, HPRegen, NewHP;

	MaxHP = RulerState.GetMaxStat(eStat_HP);
	CurrentHP = RulerState.GetCurrentStat(eStat_HP);
	HPRegen = MaxHP * ConfHealthRegen;
	NewHP = CurrentHP + HPRegen;

	UnitState.SetCurrentStat(eStat_HP, NewHP);
	RulerState.SetCurrentStat(eStat_HP, NewHP);
}

static function RegenArmor(XComGameState_Unit UnitState, XComGameState_Unit RulerState, float ConfArmorRegen)
{
	local int MaxArmor, CurrentArmor, ArmorRegen, NewArmor;

	MaxArmor = RulerState.GetMaxStat(eStat_ArmorMitigation);
	CurrentArmor = RulerState.GetCurrentStat(eStat_ArmorMitigation);
	ArmorRegen = MaxArmor * ConfArmorRegen;
	NewArmor = CurrentArmor + ArmorRegen;

	UnitState.SetCurrentStat(eStat_ArmorMitigation, NewArmor);
	RulerState.SetCurrentStat(eStat_ArmorMitigation, NewArmor);
}