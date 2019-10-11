class OPTC_CharactersRulers extends X2DownloadableContentInfo config(RulersRegen);

var config float REGEN_HEALTH;
var config float REGEN_ARMOR;

static event OnPostTemplatesCreated()
{
	local X2CharacterTemplateManager CharacterMgr;
	local array<X2DataTemplate> TemplateAllDifficulties;
	local X2DataTemplate Template;
	local X2CharacterTemplate CharacterTemplate;

	local array<Name> Rulers;
	local Name RulerName;

	Rulers.AddItem('ViperKing');
	Rulers.AddItem('BerserkerQueen');
	Rulers.AddItem('ArchonKing');
	Rulers.AddItem('CXQueen');

	`LOG("Regen Rulers loaded");

	CharacterMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();

	foreach Rulers(RulerName)
	{
		CharacterMgr.FindDataTemplateAllDifficulties(RulerName, TemplateAllDifficulties);
	
		foreach TemplateAllDifficulties(Template)
		{
			CharacterTemplate = X2CharacterTemplate(Template);
	
			if (CharacterTemplate != none)
			{
				CharacterTemplate.OnStatAssignmentCompleteFn = RegenAlienRulerHealthAndArmor;
				`LOG("Regen Rulers:" @ RulerName @ " patched");
			}
		}
	}
}

static function RegenAlienRulerHealthAndArmor(XComGameState_Unit UnitState)
{
	local XComGameStateHistory History;
	local XComGameState_AlienRulerManager RulerMgr;
	local XComGameState_Unit RulerState;
	local StateObjectReference RulerRef;
	local int MaxHP, CurrentHP, HPRegen, NewHP, MaxArmor, CurrentArmor, ArmorRegen, NewArmor;

	History = `XCOMHISTORY;
	RulerMgr = XComGameState_AlienRulerManager(History.GetSingleGameStateObjectForClass(class'XComGameState_AlienRulerManager'));
	RulerRef = RulerMgr.GetAlienRulerReference(UnitState.GetMyTemplateName());

	if (RulerRef.ObjectID != 0 && RulerRef.ObjectID != UnitState.ObjectID)
	{
		RulerState = XComGameState_Unit(History.GetGameStateForObjectID(RulerRef.ObjectID));

		MaxHP = RulerState.GetMaxStat(eStat_HP);
		CurrentHP = RulerState.GetCurrentStat(eStat_HP);
		HPRegen = MaxHP * default.REGEN_HEALTH;
		NewHP = CurrentHP + HPRegen;
		// `LOG("Regen Rulers: Escaped with " @ CurrentHP @ ". Will regen" @ HPRegen);
		// `LOG("Regen Rulers DEBUG: MaxHP " @ MaxHP);
		// `LOG("Regen Rulers DEBUG: HPRegen " @ HPRegen);
		// `LOG("Regen Rulers DEBUG: NewHP " @ NewHP);

		MaxArmor = RulerState.GetMaxStat(eStat_ArmorMitigation);
		CurrentArmor = RulerState.GetCurrentStat(eStat_ArmorMitigation);
		ArmorRegen = MaxArmor * default.REGEN_ARMOR;
		NewArmor = CurrentArmor + ArmorRegen;
		`LOG("Regen Rulers: Escaped with " @ CurrentArmor @ ". Will regen" @ NewArmor);

		UnitState.SetCurrentStat(eStat_HP, NewHP);
		UnitState.SetCurrentStat(eStat_ArmorMitigation, NewArmor);
		UnitState.bIsSpecial = RulerState.bIsSpecial;
	}
}
