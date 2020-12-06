
// state stuff

class State
{
    public InternalState __internal;
}

class InternalState
{
    public StateCore core;
    public Location location;
    public Table internal_data;
    public List<ChangeData> changes;
    public State fake;
}

class StateCore
{
    public Dictionary<Location, InternalState> tables;
    public Dictionary<InternalState, true> changed_tables;
}

class ChangeData
{
    public object old;
    public object new;
}

// definitions

class GuiDefinition
{
    public string name;
    public GuiDefinitionType definition_type;
}

enum GuiDefinitionType
{
    class,
    scope,
    dynamic,
}

class GuiClassDefinition : GuiDefinition
{
    public Table gui_element_definition;
    public List<DynamicValueDefinition> dynamic_values;
    public List<GuiDefinition> children;
    public Table style_mods;
    public Table elem_mods;
}

class GuiScopeDefinition : GuiDefinition
{
    public StateLocationDefinition scope;
    public List<GuiDefinition> children;
}

class StateLocationDefinition
{
    public Location original_location;
    public Location resolved_location; // never scoped
}

class DynamicValueDefinition
{
    public StateLocationDefinition trigger_on;
    public Function setter;
    public bool compare_before_updating;
}

class DynamicGuiDefinition : GuiScopeDefinition
{
    public DynamicGuiDefinitionType dynamic_definition_type;
}

enum DynamicGuiDefinitionType
{
    list,
}

class DynamicGuiListDefinition : DynamicGuiDefinition
{
    public StateLocationDefinition trigger_on;
}

// instance stuff

class GuiInstance
{
    public List<GuiInstancePerPlayer> instances_for_players;
    public State state;
}

class GuiInstancePerPlayer
{
    public int player_index;
    public State player_state;

    public GuiElement gui_element; // top level gui element

    public List<DynamicValueInstance> dynamic_values;
}

class DynamicValueInstance
{
    public Trigger trigger;
}

class Trigger
{
    public Condition condition;
    public Function function;
}

class Condition
{
    public List<RelativeLocation> locations;
    public TriggerOperator operator;
}

enum TriggerOperator
{
    and,
    or,
}

class RelativeLocation
{
    public RelativeLocationType locationType;
    public uint? scope_index;
}

enum RelativeLocationType
{
    state,
    player_state,
    scopes,
}
