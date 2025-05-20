

// When creating goap actions think:
/*
	GOAP gets you to the party.
	The party handles itself.
	
	GOAP is about getting into the right context.

	The agent doesn’t plan every bite of food with GOAP —
	It just planned to get to the fridge.


	Add These:
	
	one thing im thinking is 
	setTimer
	setTargetPosition() or setTargetObject()
	for animations maybe a animation manager?
	
*/

randomize();


function brainGOAP() constructor
{
	
	
	actions = {};
	goals = {};
	sensors = {};
	
	targetGoal = undefined;
	
	Log = new Logger("GOAP/Brain", true, [LogLevel.debug, LogLevel.warning]);
	
	planner = new plannerGOAP(); 
	plan = [];
	currentActionIndex = 0;  // init action index
	
	
	#region Primary User Functions
	
	addAction = function(_action)
	{
		
		var _name = _action.name;
		
		if struct_exists(actions, _name)
		{
			Log.logWarning($"Action ({_name}) Exists Already.");
			return;
		}
		
		struct_set(actions, _name, _action);
		
	}
	
	addActionsByArray = function(_actions)
	{
		for(var i=0; i<array_length(_actions); i++)
		{
			var _a = _actions[i];
			addAction(_a);
		}
	}
	
	addGoal = function(_goal)
	{
		
		var _name = _goal.name;
		
		if struct_exists(goals, _name)
		{
			Log.logWarning($"Goal ({_name}) Exists Already.");
			return;
		}
		
		struct_set(goals, _name, _goal);
		
	}
	
	addGoalsByArray = function(_goals)
	{
		for(var i=0; i<array_length(_goals); i++)
		{
			var _g = _goals[i];
			addGoal(_g);
		}
	}
	
	registerSensor = function(_name, _func)
	{
		
		if struct_exists(sensors, _name)
		{
			Log.logWarning($"Sensor ({_name}) Exists Already.");
			return;
		}
		
		struct_set(sensors, _name, _func);
		
	}
	
	getSensorData = function(_name)
	{
		var _sensor = struct_get(sensors, _name);
		
		if _sensor == undefined
		{
			Log.logWarning($"Sensor: {_name} DNE.");
			return false;
		}
		
		return _sensor();
		
	}
	
	setTargetGoal = function(_goalName)
	{
		
		//show_debug_message("Goals: "+string(goals));
		
		if !struct_exists(goals, _goalName)
		{
			Log.logWarning("Set target goal failed. Goal DNE.");
			return;
		}
		
		targetGoal = struct_get(goals, _goalName);
		
	}
	

	#endregion

	#region --- Base Helper Functions ---
	
	
	initPlan = function(_plan=[])
	{
		plan = _plan;
		currentActionIndex = 0;
	}
	
	
	generatePlan = function()
	{
	    var _startTime = current_time;
    
	    var current_state = captureSensorSnapshot();
	    var goal_state = targetGoal.conditions;
	    var available_actions = actions;
		
		//show_debug_message($"ALL Actions: {available_actions}");
		//available_actions = pruneActionsByGoal(available_actions, goal_state);
		//show_debug_message($"Filtered Actions: {available_actions}");
		
	    var new_plan = planner.createPlan(current_state, goal_state, available_actions);
	    var plan_valid = (array_length(new_plan) > 0);

	    if (!plan_valid)
	    {
			Log.logDebug("No valid plan could be generated.");
			
	        return false;
	    }

	    initPlan(new_plan); // Update plan with the new one

	    var _endTime = (current_time - _startTime);
		
		
		Log.logDebug($"New plan generated successfully in ({_endTime} ms) so abt. ({round(_endTime/16.67)} frames).");
		
		printPlan();
		
	    return true;
	}
	
	captureSensorSnapshot = function()
	{
		var _snap = {};
		
		var _sensor_names = struct_get_names(sensors);
		
		for(var i=0; i<array_length(_sensor_names); i++)
		{
			var _name = _sensor_names[i];
			
			var _val = struct_get(sensors, _name);
			
			var _funct_ran = _val();
			
			struct_set(_snap, _name, _funct_ran);
		}
		
		return _snap;
		
	}

	printPlan = function()
	{
		var _len = array_length(plan);
		
		if (_len <= 0)
		{
			show_debug_message("Print Plan - Plan is empty.");
			return;
		}
		
		show_debug_message($"({_len}) ~ Printing Plan:");
		
		//show_debug_message(string(plan));
		
		for(var a=0; a<_len; a++)
		{
			
			var _act = plan[a];
			show_debug_message($"{a+1}: {_act}");
			
		}
		
	}
	

	drawSensors = function(_x, _y)
	{
		var _sensor_names = struct_get_names(sensors);
		
		for(var i=0; i<array_length(_sensor_names); i++)
		{
			var _sensor = _sensor_names[i];
			var _val = struct_get(sensors, _sensor);
			
			draw_text(_x, (_y-(20*i)), $"Sensor: {_sensor} ~ {_val()}");
			
		}
		
	}
	
	#endregion
	
	#region		<Run the Plan>
	
	LogPlanExe = new Logger("GOAP/Brain/Plan-Executor", true, [LogLevel.warning]);
	
	checkReactionDelta = function(startState, endState, expectedChanges)
	{
	    var keys = struct_get_names(expectedChanges);

	    for (var i = 0; i < array_length(keys); i++)
	    {
	        var key = keys[i];

	        if (!struct_exists(startState, key) || !struct_exists(endState, key))
	        {
	            show_debug_message("Missing key: " + key);
	            return false;
	        }

	        var expected = expectedChanges[$ key];
	        var startVal = startState[$ key];
	        var endVal = endState[$ key];

	        // If expected is bool, just compare directly
	        if (is_bool(expected))
	        {
	            if (endVal != expected) return false;
	        }
	        else
	        {
	            var delta = endVal - startVal;
	            if (delta != expected && endVal != expected) return false;
	        }
	    }

	    return true;
	}
	
	goalComplete = function()
	{
	    //show_debug_message("[GOAP] Goal complete!");
		LogPlanExe.logInfo($"Plan Completed For Goal: {targetGoal.name}");
	    generatePlan();
	}

	handleFailure = function()
	{
	    //show_debug_message("[GOAP] Plan failed.");
	    generatePlan();
		
	}

	handleInterruption = function()
	{
	    //show_debug_message("[GOAP] Plan interrupted. Replanning...");
	    generatePlan();
	}
	
	
	hasReachedTarget = function(target)
	{
	    var target_x, target_y;
		var tolerance = 0;

	    // Handle both object and position input
	    if (instance_exists(target))
	    {
	        target_x = target.x;
	        target_y = target.y;
	    }
	    else if (is_array(target) && array_length(target) == 2)
	    {
	        target_x = target[0];
	        target_y = target[1];
	    }
	    else
	    {
	        show_debug_message("Invalid target type passed to hasReachedTarget()");
	        return true;
	    }

	    var dist = point_distance(x, y, target_x, target_y);
	    return (dist <= tolerance); // Adjust tolerance as needed
	}

	
	moveTowardTarget = function(target, spd = 2)
	{
	    var target_x, target_y;

	    if (instance_exists(target))
	    {
	        target_x = target.x;
	        target_y = target.y;
	    }
	    else if (is_array(target) && array_length(target) == 2)
	    {
	        target_x = target[0];
	        target_y = target[1];
	    }
	    else
	    {
	        show_debug_message("Invalid target type passed to moveTowardTarget()");
	        return;
	    }

	    var angle = point_direction(x, y, target_x, target_y);
	    x += lengthdir_x(spd, angle);
	    y += lengthdir_y(spd, angle);
	}

	

	doPlan = function()
	{
	    // 1. Is the Goal Already Achieved?
	    if (planner.checkKeysMatch(targetGoal.conditions, captureSensorSnapshot()))
	    {
			LogPlanExe.logInfo($"Target Goal: {targetGoal.name} Already Completed.");
	        return; // No plan needed
	    }

	    // 2. Is There a Valid Plan?
	    if (plan == undefined || array_length(plan) == 0)
	    {
			LogPlanExe.logWarning("Plan isnt valid.");
	        generatePlan();
	        return;
	    }

	    // 3. Are we done with the plan?
	    if (currentActionIndex >= array_length(plan))
	    {
	        goalComplete(); // Plan success
	        return;
	    }

	    // 4. Get the Current Action
	    var _actionName = plan[currentActionIndex];

	    if (!struct_exists(actions, _actionName))
	    {
			LogPlanExe.logWarning($"Action '{_actionName}' does not exist.");
	        handleFailure(); // Exit or replan
	        return;
	    }

	    var _action = actions[$ _actionName];

	    // 5. Preconditions must hold
	    if (!planner.checkKeysMatch(_action.conditions, captureSensorSnapshot()))
	    {
			LogPlanExe.logDebug($"Preconditions failed for '{_actionName}'. Replanning...");
	        generatePlan();
	        return;
	    }


		// 6. Target: handle MoveBeforePerforming gate
	    if (_action.targetMode == actionTargetMode.MoveBeforePerforming)
	    {
	        if (!hasReachedTarget(_action.target))
	        {
	            moveTowardTarget(_action.target);
	            return; // Don't execute until we arrive
	        }
	    }
	    else if (_action.targetMode == actionTargetMode.PerformWhileMoving)
	    {
	        moveTowardTarget(_action.target);
	    }

	    // 6. If action hasn't started, take snapshot
	    _action.startSnapshot = captureSensorSnapshot();
	    
		

	    // 7. Execute the action 
		_action.execute();
		

		// 8. Check for completion first
		if (checkReactionDelta(_action.startSnapshot, captureSensorSnapshot(), _action.reactions))
		{
			LogPlanExe.logInfo($"[GOAP] '{_actionName}' completed.");
		    currentActionIndex++;

		    // Optional: clear snapshot so action resets if reused
		    _action.startSnapshot = undefined;

		    if (currentActionIndex >= array_length(plan))
		    {
		        goalComplete();
		    }

		    return; // Exit early so no interruption is falsely detected
		}

		// 9. Then check for interruption
		if (_action.isInterruptible && !planner.checkKeysMatch(_action.conditions, captureSensorSnapshot()))
		{
			LogPlanExe.logInfo($"[GOAP] '{_actionName}' was interrupted.");
		    handleInterruption();
		    return;
		}

	}

	#endregion

}



function plannerGOAP() constructor
{
	planLog = new Logger("GOAP/Planner", true, [LogLevel.info, LogLevel.profile]);
	
	
    plan_cache = {};        // Cache for previously generated plans
	
	
	
	#region	--- Helper Functions ---

	
	hashState = function(_state)
	{
	    var keys = struct_get_names(_state);
	    array_sort(keys, true); // VERY IMPORTANT: Sort keys alphabetically
	    var str = "{";
	    for (var i = 0; i < array_length(keys); i++)
		{
	        var key = keys[i];
	        var value = _state[$ key];
	        str += string(key) + ":" + string(value); // Convert key and value to string consistently
	        if (i < array_length(keys) - 1)
			{
	            str += ",";
	        }
	    }
	    str += "}"; // Add delimiters to the start/end for clarity
	    return str;
	}
	
	
	pruneActionsByGoal = function(actions, goal_state)
	{
	    var pruned_actions = {};
	    var goal_keys = struct_get_names(goal_state);

	    var action_names = struct_get_names(actions);
	    for (var i = 0; i < array_length(action_names); i++)
		{
	        var action_name = action_names[i];
	        var action = actions[$ action_name];
        
	        // Check if action.effects change any key relevant to the goal
	        var effects_keys = struct_get_names(action.reactions);
        
	        var relevant = false;
			
	        for (var k = 0; k < array_length(effects_keys); k++)
			{
	            var effect_key = effects_keys[k];
            
	            if (array_contains(goal_keys, effect_key))
				{
					// Directly Relavant
	                // If the effect value is different from goal, it's relevant
	                //if (action.reactions[$ effect_key] != goal_state[$ effect_key])
					//{
	                //    relevant = true;
	                //    break;
	                //}
					
					// Just helps in general
					relevant = true;
	                break;
				}
	            
	        }
        
	        if (relevant)
			{
				pruned_actions[$ action_name] = action;
			} else {
				show_debug_message($"Action Not Relevant: {action_name}");
			}
	        
	    }
	    return pruned_actions;
	}
	
	
	checkKeysMatch = function(_conditions_or_reactions, _state_to_check) // Renamed parameters for clarity
	{
	    var _keys = struct_get_names(_conditions_or_reactions); // Iterate keys from the conditions/reactions set
	    for (var i = 0; i < array_length(_keys); i++)
	    {
	        var _key = _keys[i];
	        // Call keyMatches with STATE first, then CONDITIONS/REACTIONS
	        if (!keyMatches(_state_to_check, _conditions_or_reactions, _key)) // <-- Swap parameters here!
	        { 
	            return false; // If ANY key doesn't match, the whole set doesn't match
	        }
	    }
	    return true; // If all keys matched, the whole set matches
	}

	
	keyMatches = function(_state_to_check, _target_struct, _key_to_check)
	{
	    // Check if the key exists in the state we are checking against
	    if (!struct_exists(_state_to_check, _key_to_check))
	    {
	        // If the key isn't in the state, the condition isn't met.
	        // planLog.logDebug($"keyMatches: Key '{_key_to_check}' not found in state."); // Optional debug
	        return false;
	    }

	    var state_value = _state_to_check[$ _key_to_check];
	    var condition_definition = _target_struct[$ _key_to_check]; // Get the condition definition from the target struct (either goal or action conditions)


	    // --- Handle Numerical Conditions (Condition definition is a struct with comparison and value) ---
	    if (is_struct(condition_definition) && struct_exists(condition_definition, "comparison") && struct_exists(condition_definition, "value"))
	    {
	        var operator = condition_definition.comparison;
	        var target_value = condition_definition.value;

	        // Ensure both state value and target value are numeric for numerical comparison
	        if (!is_numeric(state_value) || !is_numeric(target_value))
	        {
	            // If either isn't numeric, the condition can't be numerically matched.
	            planLog.logError($"keyMatches: Numerical comparison for key '{_key_to_check}' requires numeric values. State is '{string(state_value)}', Target is '{string(target_value)}'.");
	            return false;
	        }

	        var result = false; // Initialize the boolean result for the comparison

	        // Perform the numerical comparison based on the operator string
	        switch (operator)
	        {
	            case ">=": result = state_value >= target_value; break;
	            case "<=": result = state_value <= target_value; break;
	            case ">":  result = state_value > target_value; break;
	            case "<":  result = state_value < target_value; break;
	            case "=":  result = state_value == target_value; break;

	            default:
	                planLog.logError($"keyMatches: Unknown comparison operator '{operator}' for key '{_key_to_check}'.");
	                return false; // An unknown operator means the condition is not met
	        }

	        return result; // Return the actual boolean result of the numerical comparison
	    }
	    // --- Handle Simple Boolean/Value Conditions (Condition definition is a direct value) ---
	    else
	    {
	        var condition_value = condition_definition;

	        // For simple conditions, the state value must exactly match the condition value.
	        // We already checked if the key exists in the state.
	        return state_value == condition_value;
	    }
	}
	

	reconstructPath = function(goal_node) // goal_node is the final astarNode
	{
	    var actions = []; // This array will store ACTION NAMES (strings)
	    // Start from the goal node and walk back through parents
	    var current = goal_node; // 'current' should be an astarNode

	    if (current == undefined)
		{
	        //show_debug_message("reconstructPath: Started with undefined goal_node!"); // Should not happen if a path was found
	        return [];
	    }

	    // While current node is valid and has a parent (i.e., not the start node)
	    while (current != undefined && current.parent != undefined) // <-- Error is reported on this line
		{
	        array_push(actions, current.action); // Collect the action NAME (string)
	        current = current.parent; // Move up to the parent node
	    }

	    // The actions are collected in reverse order, so reverse them for correct sequence
	    actions = array_reverse(actions); // Array of strings

	    return actions; // Returns array of action names
	}


	// Generate a unique cache key for a given start state and goal conditions.
	// This key is used to store and retrieve plans from the plan_cache.
	generateCacheKey = function(_startState, _goalConditions)
	{
		// Combine the hash of the start state and the hash of the goal conditions.
		// Ensure goal conditions are also hashed consistently (e.g., sort keys).
		var start_state_hash = hashState(_startState);
		var goal_conditions_hash = hashState(_goalConditions); // Assuming goal conditions are a struct

		return start_state_hash + "|" + goal_conditions_hash; // Use a separator that won't appear in hashes
	}
	
	
	// --- Simulate applying an action's reactions to a state ---
    simulateReactions = function(_state, _reactions)
    {
		//show_debug_message("simulating");
		
        var new_state = variable_clone(_state); // Start with a copy of the current state
        var reaction_keys = struct_get_names(_reactions);

        for (var i = 0; i < array_length(reaction_keys); i++)
        {
            var key = reaction_keys[i];
            var reaction_value = _reactions[$ key];

            // Check if the state variable exists before attempting to modify it
            // If the reaction is to add a new state variable, add it.
            if (!struct_exists(new_state, key))
			{
                 new_state[$ key] = reaction_value;
                 planLog.logDebug($"Simulating Reaction: Added new key '{key}' with value '{string(reaction_value)}'");
                 continue; // Move to the next reaction
            }

            // --- CORRECTED LOGIC FOR APPLYING REACTIONS ---
            // Prioritize setting boolean values if the reaction value is a boolean.
            if (is_bool(reaction_value))
            {
                 new_state[$ key] = reaction_value; // Direct assignment for booleans
                 planLog.logDebug($"Simulating Reaction: Key '{key}' set to boolean '{string(reaction_value)}'.");
            }
            // Handle numerical changes (+N, -N) ONLY if the reaction value is numeric AND the state value is numeric
            else if (is_numeric(reaction_value) && is_numeric(new_state[$ key]))
            {
                new_state[$ key] += reaction_value; // Apply the numerical change (add or subtract)
                planLog.logDebug($"Simulating Reaction: Key '{key}' numerical change by {string(reaction_value)}. New value: {string(new_state[$ key])}");
            }
            // For all other cases (strings, or numbers for non-numeric state properties, or direct number assignments),
            // treat it as a direct SET value.
            else
            {
                 new_state[$ key] = reaction_value; // Direct assignment
                 planLog.logDebug($"Simulating Reaction: Key '{key}' set to '{string(reaction_value)}'.");
            }


        }
        return new_state;
    }
	
	
	
	structToArray = function(_struct)
	{
		var _finalArray = [];
		
		var _keys = struct_get_names(_struct);
		
		for(var i=0; i<array_length(_keys); i++)
		{
			array_push(_finalArray, _struct[$ _keys[i]]);
		}
		
		return _finalArray;
		
	}
	
	
	
	getPlanActionNames = function(_plan)
	{
		var _temp = [];
		for(var i=0; i<array_length(_plan); i++)
		{
			var _act = _plan[i];
			var _name = _act.name;
			
			array_push(_temp, _name);
		}
		
		return _temp;
	}
	
	getPlanCost = function(_plan)
	{
		var _total = 0;
		for(var i=0; i<array_length(_plan); i++)
		{
			var _act = _plan[i];
			var _cost = _act.cost;
			//var _name = _act.name;
			
			_total += _cost;
		}
		
		return _total;
	}
	
	
	
	/// @desc Returns a struct of relevant actions needed to achieve the goal.
	/// @param actions - struct of all possible GOAP actions (by name or ID)
	/// @param goal - struct representing the desired goal state
	/// @returns struct of relevant actions
	backwardPlanning = function(actions, goal)
	{
	    var neededKeys = struct_get_names(goal);
	    var visitedKeys = [];
	    var relevantActions = {};

	    var foundNew = true;
	    while (foundNew) {
	        foundNew = false;

	        var allKeys = struct_get_names(actions);
	        for (var i = 0; i < array_length(allKeys); i++) {
	            var key = allKeys[i];
	            var act = actions[$ key];

	            var reactionKeys = is_struct(act.reactions) ? struct_get_names(act.reactions) : [];

	            // Manually check if any reactionKey matches a neededKey
	            var matches = false;
	            for (var r = 0; r < array_length(reactionKeys); r++) {
	                if (array_contains(neededKeys, reactionKeys[r])) {
	                    matches = true;
	                    break;
	                }
	            }

	            if (matches) {
	                if (!struct_exists(relevantActions, key)) {
	                    relevantActions[$ key] = act;
	                    foundNew = true;
	                }

	                var condKeys = is_struct(act.conditions) ? struct_get_names(act.conditions) : [];
	                for (var j = 0; j < array_length(condKeys); j++) {
	                    var condKey = condKeys[j];
	                    if (!array_contains(neededKeys, condKey) && !array_contains(visitedKeys, condKey)) {
	                        array_push(neededKeys, condKey);
	                        array_push(visitedKeys, condKey);
	                        foundNew = true;
	                    }
	                }
	            }
	        }
	    }

	    return relevantActions;
	}
	
	
	goalProgressCount = function(_state, _goalState)
	{
	    var count = 0;
	    var keys = struct_get_names(_goalState);
	    var totalKeys = array_length(keys);
    
	    for (var i = 0; i < totalKeys; i++)
	    {
	        var key = keys[i];
	        if (struct_exists(_state, key) && _state[$ key] == _goalState[$ key])
	        {
	            count++;
	        } 
	        else 
	        {
	            //count--;
	        }
	    }
		//show_debug_message($"Count: {count}");
	    // Add base to shift score into positive range
	    return count// + totalKeys; // score will be between 0 and totalKeys * 2
	}



	
	/// @param array     The array to slice
	/// @param start     The start index (0-based)
	/// @param length    The number of elements to include
	/// @returns         A new array with the sliced elements

	array_slice = function(_array, _start, _length)
	{
	    var _result = [];
	    var _end = _start + _length;
	    var _count = array_length(_array);
    
	    // Clamp the end to array bounds
	    if (_start < 0) _start = 0;
	    if (_end > _count) _end = _count;

	    for (var i = _start; i < _end; i++)
		{
	        array_push(_result, _array[i]);
	    }

	    return _result;
	}


	isActionDominated = function(a1, a2)
	{
	    // Check if a2 has all of a1's effects and they are >= in value
	    var a1Reactions = a1.reactions;
	    var a2Reactions = a2.reactions;
	    var keysA1 = struct_get_names(a1Reactions);

	    for (var i = 0; i < array_length(keysA1); i++)
	    {
	        var key = keysA1[i];

	        if (!struct_exists(a2Reactions, key)) return false;

	        var valA1 = a1Reactions[$ key];
	        var valA2 = a2Reactions[$ key];

	        if (is_real(valA1) && is_real(valA2))
	        {
	            if (valA2 < valA1) return false; // a2's value must be >= a1
	        }
	        else if (valA1 != valA2)
	        {
	            return false; // must match exactly if not numeric
	        }
	    }

	    // Check for side effects — a2 must not have extra reactions a1 doesn't
	    var keysA2 = struct_get_names(a2Reactions);
	    for (var j = 0; j < array_length(keysA2); j++)
	    {
	        if (!struct_exists(a1Reactions, keysA2[j]))
	        {
	            return false; // a2 has an effect a1 doesn't — side effect
	        }
	    }

	    // Check cost
	    var cost1 = a1.cost ?? 1;
	    var cost2 = a2.cost ?? 1;
	    if (cost2 > cost1) return false;

	    return true; // a1 is dominated by a2
	}




	filterDominatedActions = function(_allActions, _state)
	{
	    var filtered = [];

	    for (var a = 0; a < array_length(_allActions); a++)
	    {
	        var actA = _allActions[a];
	        if (!checkKeysMatch(actA.conditions, _state)) continue;

	        var dominated = false;

	        for (var b = 0; b < array_length(_allActions); b++)
	        {
	            if (a == b) continue;
				
	            var actB = _allActions[b];
	            if (!checkKeysMatch(actB.conditions, _state)) continue;

	            if (isActionDominated(actA, actB))
	            {
	                dominated = true;
	                break;
	            }
	        }

	        if (!dominated)
	        {
	            array_push(filtered, actA);
	        }
	    }

	    return filtered;
	}

	
	/// calculateDynamicBeamWidth(currentState, goalState, minBeam, maxBeam)
	/// Returns an adaptive beam width based on goal proximity

	calculateDynamicBeamWidth = function(_currentState, _goalState, _min=2, _max=8)
	{
	    var progress = goalProgressCount(_currentState, _goalState);
	    var total = array_length(struct_get_names(_goalState));
    
	    if (total <= 0) return _min; // fallback

	    var closeness = progress / total; // 0.0 = far, 1.0 = near
	    return clamp(round(lerp(_max, _min, closeness)), _min, _max);
	}

	

	#endregion


	findPlan = function(_startState, _goalState, _actions, _minBeam=2, _maxBeam=10, _numOfPlans=3)
	{
	    show_debug_message($"Before Filter - Actions: {array_length(struct_get_names(_actions))}");

	    var _allActions = structToArray(_actions);

	    show_debug_message($"After Filter - Actions: {array_length(getPlanActionNames(_allActions))}");

	    var _visited = {};
	    var _plans = [];

	    // Initialize first level with start state
	    var _level = [{
	        state: _startState,
	        plan: [],
	        score: goalProgressCount(_startState, _goalState)
	    }];

	    while (array_length(_level) > 0 && array_length(_plans) < _numOfPlans)
	    {
	        var _nextLevel = [];

	        for (var i = 0; i < array_length(_level); i++)
	        {
	            var _node = _level[i];
	            var _state = _node.state;
	            var _plan = _node.plan;

	            // Calculate beam width dynamically for this node
	            var dynamicBeam = calculateDynamicBeamWidth(_state, _goalState, _minBeam, _maxBeam);

	            // 1. Gather applicable actions with scores
	            var candidateActions = [];
	            for (var a = 0; a < array_length(_allActions); a++)
	            {
	                var act = _allActions[a];
	                if (checkKeysMatch(act.conditions, _state))
	                {
	                    var newState = simulateReactions(_state, act.reactions);
	                    var _score = goalProgressCount(newState, _goalState);
	                    array_push(candidateActions, { action: act, score: _score });
	                }
	            }

	            // 2. Sort descending by score (progress to goal)
	            array_sort(candidateActions, function(a, b)
				{
	                //return a.score - b.score;
	                return b.score - a.score;	// better
	            });

	            // 3. Prune candidate actions to dynamic beam width
	            if (array_length(candidateActions) > dynamicBeam)
	                candidateActions = array_slice(candidateActions, 0, dynamicBeam);

	            // 4. Expand each candidate action
	            for (var a = 0; a < array_length(candidateActions); a++)
	            {
	                var act = candidateActions[a].action;

	                var newState = simulateReactions(_state, act.reactions);
	                var newHash = hashState(newState);
	                if (struct_exists(_visited, newHash)) continue;

	                var newPlan = variable_clone(_plan);
	                array_push(newPlan, act);

	                if (checkKeysMatch(_goalState, newState))
	                {
	                    array_push(_plans, {
	                        plan: getPlanActionNames(newPlan),
	                        planCost: getPlanCost(newPlan)
	                    });
	                    if (array_length(_plans) >= _numOfPlans) break;
	                }

	                array_push(_nextLevel, {
	                    state: newState,
	                    plan: newPlan,
	                    score: goalProgressCount(newState, _goalState)
	                });

	                struct_set(_visited, newHash, true);
	            }

	            if (array_length(_plans) >= _numOfPlans) break;
	        }

	        // Sort next level by score descending
	        array_sort(_nextLevel, function(a, b) {
	            return b.score - a.score;
	        });

	        // Prune next level to maxCandidates = dynamicBeam * 2 for speed
	        var maxCandidates = dynamicBeam * 2;
	        if (array_length(_nextLevel) > maxCandidates)
	            _nextLevel = array_slice(_nextLevel, 0, maxCandidates);

	        // Prepare for next iteration, slice to dynamicBeam
	        _level = array_slice(_nextLevel, 0, dynamicBeam);
	    }

	    return _plans;
	}

	
	createPlan = function(_start_state, _goal_state, _actions)
	{
		
		show_debug_message("Create Plan started...");
	    

		// --- Check Plan Cache ---
		var cache_key = generateCacheKey(_start_state, _goal_state);
		if (struct_exists(plan_cache, cache_key))
		{
			var cached_plan = struct_get(plan_cache, cache_key);
			planLog.logInfo($"Plan found in cache for state/goal: {cache_key}. Using cached plan.");
			return cached_plan; // Return the cached plan immediately
		}

		
		var _finalPlan = findPlan(_start_state, _goal_state, _actions, 2, 7, 1);
		
		
		return _finalPlan;	//	return a array with names of the actions as strings
	}


}



#region Node Stuff


function nodeGOAP(_name) constructor
{
	//uuid = "node_"//+generateUUID(8);
	
	name = _name;
	
	conditions = {};
	
	
	showDebug = false; 
	
	
	addCondition = function(_name, _comp, _val)
	{
		if (struct_exists(conditions, _name))
		{
			if showDebug show_debug_message($"Condition ({_name}) Exists Already.");
			return;
		}
		
		struct_set(conditions, _name, {comparison: _comp , value: _val});
		
	}
	
	addSimpleCondition = function(_name, _val)
	{
		if (struct_exists(conditions, _name))
		{
			if showDebug show_debug_message($"Condition ({_name}) Exists Already.");
			return;
		}
		
		struct_set(conditions, _name, _val);
	}
	
	addEualToCondition = function(_name, _val) { addCondition(_name, "=", _val); }
	addGreaterThanCondition = function(_name, _val) { addCondition(_name, ">", _val); }
	addGreaterThanOrEqualToCondition = function(_name, _val) { addCondition(_name, ">=", _val); }
	addLessThanCondition = function(_name, _val) { addCondition(_name, "<", _val); }
	addLessThanOrEqualToCondition = function(_name, _val) { addCondition(_name, "<=", _val); }
	
	
}


enum actionStatus
{
	idle,
	running,
	success,
	failure,
}

enum actionTargetMode
{
	none,
	MoveBeforePerforming,
	PerformWhileMoving,
}

function actionGOAP(_name, _cost) : nodeGOAP(_name) constructor
{
	cost = _cost;
	reactions = {};
	isInterruptible = false;
	
	target = undefined;
	targetMode = actionTargetMode.none;
	
	status = actionStatus.idle; //idle, running, success, failure
	
	executeFunction = undefined;
	
	
	#region		--- Public User Functions
	
	addReaction = function(_name, _val)
	{
		if (struct_exists(reactions, _name))
		{
			if showDebug show_debug_message($"Reaction ({_name}) Exists Already.");
			return;
		}
		
		
		struct_set(reactions, _name, _val);
	}
	
    setExecuteFunction = function(_func)
	{
        executeFunction = _func;  // Set the function that executes the action
    }
	
	
	setTarget = function(_target, _mode=actionTargetMode.MoveBeforePerforming)
	{
		target = _target;
		targetMode = _mode;
	}
	
	
	
    
	canBeInterrupted = function(_val)
	{
		isInterruptible = _val;
	}

	#endregion	
	
    // Function to execute the action
    execute = function()
	{
        if (executeFunction != undefined)
		{
            executeFunction();  // Call the function to execute the action
        }
        
    }
	
	
	isRunning = function()
	{
		return (status == actionStatus.running);
	}
	
}


function goalGOAP(_name) : nodeGOAP(_name) constructor
{
	
	
	
}


#endregion



#region --- Example

/*


// --- Real World State Variables for the AI ---
// These are the actual stats/flags the AI instance holds
real_has_weapon = false;
real_ammo = 0;
real_scrap = 0; // Start with 0 scrap
real_weapon_needs_repair = false; // Weapon is NOT broken if we don't have one


// Create an instance of the GOAP brain
goap_brain = new brainGOAP();

// --- Define and Register Sensors ---
// Sensor for HasWeapon (boolean)
goap_brain.registerSensor("HasWeapon", function()
{
    return real_has_weapon; // Read the actual boolean stat
});

// Sensor for Ammo (numerical)
goap_brain.registerSensor("Ammo", function()
{
    return real_ammo; // Read the actual numerical stat
});

// Sensor for Scrap (numerical)
goap_brain.registerSensor("Scrap", function()
{
    return real_scrap; // Read the actual numerical stat
});

// Sensor for WeaponNeedsRepair (boolean)
goap_brain.registerSensor("WeaponNeedsRepair", function()
{
    return real_weapon_needs_repair; // Read the actual boolean stat
});


// --- Define Goal ---
// Goal: Have a weapon, enough ammo, and the weapon is NOT broken
var goal_armed_and_ready = new goalGOAP("ArmedAndReady");
// Goal conditions using numerical and simple formats
goal_armed_and_ready.addSimpleCondition("HasWeapon", true);
goal_armed_and_ready.addGreaterThanOrEqualToCondition("Ammo", 10);
goal_armed_and_ready.addSimpleCondition("WeaponNeedsRepair", false); // Goal is NOT needing repair

// Add the goal to the brain
goap_brain.addGoal(goal_armed_and_ready);


// Action: Find Weapon (Cost 10)
var action_find_weapon = new actionGOAP("FindWeapon", 10);
action_find_weapon.addSimpleCondition("HasWeapon", false);
// Reactions: Gain weapon, and it needs repair
action_find_weapon.addReaction("HasWeapon", true);
action_find_weapon.addReaction("WeaponNeedsRepair", true);
// onEntry: Change the real world state
action_find_weapon.setExecuteFunction(function() // Assuming AI instance accessible via 'self' or passed
{
    show_debug_message("AI is finding a weapon...");
    real_has_weapon = true;
    real_weapon_needs_repair = true;
	show_debug_message("AI is has a weapon");
});


// Action: Collect Scrap (Cost 5)
var action_collect_scrap = new actionGOAP("CollectScrap", 5);
// Conditions: None for simplicity in this example
//action_collect_scrap.addLessThanCondition("Scrap", 50);
// Reaction: Gain 15 scrap
action_collect_scrap.addReaction("Scrap", +15);
// onEntry: Change the real world state
action_collect_scrap.setExecuteFunction(function() // Assuming AI instance accessible via 'self' or passed
{
    show_debug_message("AI is collecting scrap...");
    real_scrap += 15; // Add scrap to the real AI stat
    show_debug_message("AI collected scrap. Total scrap: " + string(real_scrap));
});


// Action: Craft Ammo (Cost 8)
var action_craft_ammo = new actionGOAP("CraftAmmo", 8);
// Conditions: Need enough scrap, and need a weapon
action_craft_ammo.addGreaterThanOrEqualToCondition("Scrap", 5);
action_craft_ammo.addSimpleCondition("HasWeapon", true);
// Reactions: Spend 5 scrap, gain 10 ammo
action_craft_ammo.addReaction("Scrap", -5);
action_craft_ammo.addReaction("Ammo", +10);
// onEntry: Change the real world state
action_craft_ammo.setExecuteFunction(function()
{
    show_debug_message("AI is crafting ammo...");
    real_scrap -= 5; // Deduct scrap from real AI stat
    real_ammo += 10; // Add ammo to real AI stat
	show_debug_message($"AI crafting ammo: Scrap: {real_scrap}, Ammo: {real_ammo}");
    show_debug_message("AI crafted ammo. Scrap: " + string(real_scrap) + ", Ammo: " + string(real_ammo));
});


// Action: Repair Weapon (Cost 12)
var action_repair_weapon = new actionGOAP("RepairWeapon", 12);
// Conditions: Weapon needs repair, need enough scrap, need a weapon
action_repair_weapon.addSimpleCondition("WeaponNeedsRepair", true);
action_repair_weapon.addGreaterThanOrEqualToCondition("Scrap", 10);
action_repair_weapon.addSimpleCondition("HasWeapon", true);
// Reactions: Spend 10 scrap, weapon no longer needs repair
action_repair_weapon.addReaction("Scrap", -10);
action_repair_weapon.addReaction("WeaponNeedsRepair", false);
// onEntry: Change the real world state
action_repair_weapon.setExecuteFunction(function()
{
    show_debug_message("AI is repairing weapon...");
    real_scrap -= 10; // Deduct scrap from real AI stat
    real_weapon_needs_repair = false; // Set weapon as repaired
    show_debug_message("AI repaired weapon. Scrap: " + string(real_scrap) + ", Needs Repair: " + string(real_weapon_needs_repair));
});


// Add actions to the brain
goap_brain.addActionsByArray([
    action_find_weapon,
    action_collect_scrap,
    action_craft_ammo,
    action_repair_weapon
]);


// --- Set the Target Goal ---
goap_brain.setTargetGoal("ArmedAndReady");

show_debug_message("Starting GOAP brain with 'Get Armed' goal...");
goap_brain.generatePlan();
// In your Step event, you would then call goap_brain.runPlan();

*/

#endregion


