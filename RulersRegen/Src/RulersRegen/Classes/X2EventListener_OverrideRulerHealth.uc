class X2EventListener_OverrideRulerHealth extends X2EventListener config(RulersRegen);

struct RulerStatRule
{
	var ECharStatType Stat;

	var bool SetPercentMax;
	var bool SetPercentCurrent;
	var bool SetFlatBonus;
	var bool SetPerEncounterValue;

	var float PercentMax;
	var float PercentCurrent;
	var int FlatBonus;
	var int PerEncounterValue;

	var bool SetOvercap;
};

struct RulerRuleSet
{
	var name RulerTemplateName;
	var array<RulerStatRule> Rules;
};

var config array<RulerRuleSet> RulerRuleSets;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateRulerEscapedListener());

	return Templates;
}

static function CHEventListenerTemplate CreateRulerEscapedListener()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'RegenEscapedRuler');

	Template.RegisterInTactical = true;
	Template.RegisterInStrategy = false;
	Template.AddCHEvent('PostRulerTacticalTransfer', OverrideRulerEscapeStats, ELD_Immediate);

	return Template;
}

static function EventListenerReturn OverrideRulerEscapeStats(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit UnitState;
	local XComGameState_Unit RulerState;
	local int Encounters;
	local array<RulerStatRule> Rules;

	Tuple = XComLWTuple(EventData);

	if (Tuple == none || Tuple.Id != 'PostRulerTacticalTransfer')
	{
		return ELR_NoInterrupt;
	}

	UnitState  = XComGameState_Unit(Tuple.Data[0].o);
	RulerState = XComGameState_Unit(Tuple.Data[1].o);

	if (UnitState == none || RulerState == none)
	{
		return ELR_NoInterrupt;
	}

	if (UnitState.IsDead())
	{
		return ELR_NoInterrupt;
	}

	Encounters = class'X2Helpers_DLC_Day60'.static.GetRulerNumAppearances(UnitState);

	Rules = GetRulesForRuler(RulerState.GetMyTemplateName());

	if (Rules.Length == 0)
	{
		return ELR_NoInterrupt;
	}

	ApplyRules(RulerState, Rules, Encounters);

	class'X2Helpers_DLC_Day60'.static.UpdateRulerEscapeHealth(RulerState);

	return ELR_NoInterrupt;
}

static function array<RulerStatRule> GetRulesForRuler(name TemplateName)
{
	local int i;
	local array<RulerStatRule> Empty;

	for (i = 0; i < default.RulerRuleSets.Length; i++)
	{
		if (default.RulerRuleSets[i].RulerTemplateName == TemplateName)
		{
			return default.RulerRuleSets[i].Rules;
		}
	}

	for (i = 0; i < default.RulerRuleSets.Length; i++)
	{
		if (default.RulerRuleSets[i].RulerTemplateName == '')
		{
			return default.RulerRuleSets[i].Rules;
		}
	}

	return Empty;
}

static function ApplyRules(XComGameState_Unit RulerState, array<RulerStatRule> Rules, int Encounters)
{
	local int i;
	local RulerStatRule Rule;
	local int Current, Max, NewValue;

	for (i = 0; i < Rules.Length; i++)
	{
		Rule = Rules[i];

		switch (Rule.Stat)
		{
			case eStat_HP:
			case eStat_Offense:
			case eStat_Defense:
			case eStat_Mobility:
			case eStat_Will:
			case eStat_SightRadius:
			case eStat_Dodge:
			case eStat_ArmorMitigation:
			case eStat_ArmorPiercing:
			case eStat_PsiOffense:
			case eStat_DetectionRadius:
			case eStat_CritChance:
			case eStat_Strength:
			case eStat_FlankingCritChance:
			case eStat_ShieldHP:
			case eStat_FlankingAimBonus:

				Current = RulerState.GetCurrentStat(Rule.Stat);
				Max = RulerState.GetMaxStat(Rule.Stat);

				NewValue = ResolveStat(Current, Max, Rule, Encounters);

				if (NewValue > Max)
				{
					RulerState.SetBaseMaxStat(Rule.Stat, NewValue, ECSMAR_Additive);
				}

				RulerState.SetCurrentStat(Rule.Stat, NewValue);
				break;

			default:
				break;
		}
	}
}

static function int ResolveStat(int Current, int Max, RulerStatRule Rule, int Encounters)
{
	local int Value;

	if (Rule.SetFlatBonus)
	{
		Value = Current + Rule.FlatBonus;
	}
	else if (Rule.SetPercentMax)
	{
		Value = Max * Rule.PercentMax;
	}
	else if (Rule.SetPercentCurrent)
	{
		Value = Current * Rule.PercentCurrent;
	}
	else
	{
		Value = Current;
	}

	if (Rule.SetPerEncounterValue)
	{
		Value += Rule.PerEncounterValue * Encounters;
	}

	if (Rule.SetOvercap)
	{
		return Value;
	}

	return Clamp(Value, 0, Max);
}