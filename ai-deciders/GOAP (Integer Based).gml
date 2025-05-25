

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


function structToArray(_struct)
{
	var _finalArray = [];
		
	var _keys = struct_get_names(_struct);
		
	for(var i=0; i<array_length(_keys); i++)
	{
		array_push(_finalArray, _struct[$ _keys[i]]);
	}
		
	return _finalArray;
		
}
	

function hashState(_state)
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


function brainGOAP() constructor
{
	actions = {};
	goals = {};
	sensors = {};
	
	targetGoal = undefined;
	
	Log = new Logger("GOAP/Brain", true, [LogLevel.debug, LogLevel.warning]);
	
	planner = new plannerGOAP(actions); 
	plan = [];
	currentActionIndex = 0;  // init action index
	
	
	
	#region		- Primary User Functions -
	
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

	#region		[Base Helper Functions]
	
	
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
		
		
	    var new_plan = planner.createPlan(current_state, goal_state);
		
	    var plan_valid = (array_length(new_plan) > 0);

	    if (!plan_valid)
	    {
			Log.logDebug("No valid plan could be generated.");
			
	        return false;
	    }

	    initPlan(new_plan); // Update plan with the new one

	    var _endTime = (current_time - _startTime);
		
		
		Log.logDebug($"New plan: ({array_length(new_plan)}) generated successfully in ({_endTime} ms) so abt. ({round(_endTime/16.67)} frames).");
		
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



function plannerGOAP(_allActions) constructor
{
	planLog = new Logger("GOAP/Planner", true, [LogLevel.info, LogLevel.warning, LogLevel.profile]);
	
    plan_cache = {};        // Cache for previously generated plans
	
	
	allActions = _allActions;
	
	conditionGraph = undefined;	// init ONCE
	reactionGraph = undefined; // init ONCE
	
	actionCostData = undefined; // init ONCE
	
	#region	--- Helper Functions ---

	setupActionData = function()
	{
		if (is_undefined(conditionGraph) and is_undefined(reactionGraph))
		{
			var _graphs = planLog.doProfile("buildDependencyMaps",buildDependencyMaps);
			conditionGraph = _graphs.con;
			reactionGraph = _graphs.react;
			
			actionCostData = calculateMinActionCostsHeuristicData();
		}
		
	}
	
	
	
	checkKeysMatch = function(_conditions_or_reactions, _state_to_check) // Renamed parameters for clarity
	{
	    var _keys = struct_get_names(_conditions_or_reactions); // Iterate keys from the conditions/reactions set
	    for (var i = 0; i < array_length(_keys); i++)
	    {
	        var _key = _keys[i];
	        // Call keyMatches with STATE first, then CONDITIONS/REACTIONS
	        if (!keyMatches(_state_to_check, _conditions_or_reactions, _key)) 
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
	    if (is_struct(condition_definition))
	    {
	        var operator = condition_definition.comparison;
	        var target_value = condition_definition.value;

	        // Ensure both state value and target value are numeric for numerical comparison
	        if (!is_numeric(state_value) || !is_numeric(target_value))
	        {
	            // If either isn't numeric, the condition can't be numerically matched.
	            planLog.logWarning($"keyMatches: Numerical comparison for key '{_key_to_check}' requires numeric values. State is '{string(state_value)}', Target is '{string(target_value)}'.");
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
	                planLog.logWarning($"keyMatches: Unknown comparison operator '{operator}' for key '{_key_to_check}'.");
	                return false; // An unknown operator means the condition is not met
	        }
			
			if (!result)
			{
				//show_debug_message("keyMatches: Numeric condition failed for key '" + string(_key_to_check) + "'. State: " + string(state_value) + " " + string(operator) + " " + string(target_value));
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
	
	
	
	getUnmetConditions = function(_conditions, _state)
	{
		var unmet = [];
		var _keys = struct_get_names(_conditions);

		for (var i = 0; i < array_length(_keys); i++)
		{
			var _key = _keys[i];

			if (!keyMatches(_state, _conditions, _key))
			{
				array_push(unmet, _key);
			}
		}
	
		return unmet;
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

	
	anyKeysMatch = function(_keysA, _keysB)
	{ 
		
		_keysA = struct_get_names(_keysA);
		_keysB = struct_get_names(_keysB);
		
	    for (var i = 0; i < array_length(_keysA); i++)
		{
	        var _keyA = _keysA[i];
	        for (var j = 0; j < array_length(_keysB); j++)
			{
	            var _keyB = _keysB[j];
	            if (_keyA == _keyB)
				{
	                return true; // Found a match, no need to check further
	            }
	        }
	    }
	    return false; // No common keys found after checking all combinations
	}

	
	buildActionDependencyGraph = function()
	{
	    var _allActs = structToArray(allActions);
	    var _forwardGraph = {};
	    var _backwardGraph = {};

	    for (var i = 0; i < array_length(_allActs); i++)
	    {
	        var _actA = _allActs[i];
	        var _forwardList = [];

	        for (var j = 0; j < array_length(_allActs); j++)
	        {
	            var _actB = _allActs[j];

	            //if (checkKeysMatch(_actB.conditions, _actA.reactions))
	            if (anyKeysMatch(_actB.conditions, _actA.reactions))
	            {
	                // Forward: A -> B
	                array_push(_forwardList, _actB.name);

	                // Backward: B <- A
	                if (!struct_exists(_backwardGraph, _actB.name))
	                {
	                    _backwardGraph[$ _actB.name] = [];
	                }
	                array_push(_backwardGraph[$ _actB.name], _actA.name);
	            }
	        }

	        _forwardGraph[$ _actA.name] = _forwardList;

	        // Ensure all nodes exist in both graphs, even if empty
	        if (!struct_exists(_backwardGraph, _actA.name))
	        {
	            _backwardGraph[$ _actA.name] = [];
	        }
	    }

	    return {
	        forward: _forwardGraph,
	        backward: _backwardGraph
	    };
	}


	buildDependencyMaps = function()
	{
		var _allActions = structToArray(allActions);
	    var preMap = {};
	    var effMap = {};

	    for (var k = 0; k < array_length(_allActions); k++)
		{
	        var act = _allActions[k];

	        var condKeys = struct_get_names(act.conditions);
	        for (var i = 0; i < array_length(condKeys); i++)
			{
	            var key = condKeys[i];
	            if (!struct_exists(preMap, key)) preMap[$ key] = [];
	            array_push(preMap[$ key], act.name);
	        }

	        var effectKeys = struct_get_names(act.reactions);
	        for (var i = 0; i < array_length(effectKeys); i++)
			{
	            var key = effectKeys[i];
	            if (!struct_exists(effMap, key)) effMap[$ key] = [];
	            array_push(effMap[$ key], act.name);
	        }
	    }

	    return {con: preMap, react: effMap};
	}
	
	// Find Actions That Depend On the Current Action
	getDependentActions = function(currentActionName)
	{
	    var action = allActions[$ currentActionName];
	    if (action == undefined) return [];

	    var dependentActions = [];
	    var reactKeys = struct_get_names(action.reactions);

	    for (var i = 0; i < array_length(reactKeys); i++)
	    {
	        var key = reactKeys[i];
	        var consumers = reactionGraph[$ key]; // <- actions that consume this key
	        if (consumers != undefined)
	        {
	            for (var j = 0; j < array_length(consumers); j++)
	            {
	                var actName = consumers[j];
	                if (!array_contains(dependentActions, actName))
					{
	                    array_push(dependentActions, actName);
					}
	            }
	        }
	    }

	    return dependentActions;
	}

	//  Find Actions That Enable the Current Action
	getEnablingActions = function(currentActionName)
	{
	    var action = allActions[$ currentActionName];
	    if (action == undefined) return [];

	    var enablingActions = [];
	    var condKeys = struct_get_names(action.conditions);

	    for (var i = 0; i < array_length(condKeys); i++)
	    {
	        var key = condKeys[i];
	        var producingActs = conditionGraph[$ key]; // <- actions that produce this key
	        if (producingActs != undefined)
	        {
	            for (var j = 0; j < array_length(producingActs); j++)
	            {
	                var actName = producingActs[j];
	                if (!array_contains(enablingActions, actName))
	                    array_push(enablingActions, actName);
	            }
	        }
	    }

	    return enablingActions;
	}


	getUnmetConditionsIterative = function(_conditions, _state)
	{
	    var unmetConditions = {}; // Use a dictionary/object to store unique unmet keys
	    var visitedKeys = [];
	    var queue = [];

	    // Initialize the queue with the initial conditions
	    var initialKeys = struct_get_names(_conditions);
	    for (var i = 0; i < array_length(initialKeys); i++)
	    {
	        var key = initialKeys[i];
	        if (!keyMatches(_state, _conditions, key))
	        {
	            // Only add to queue and unmetConditions if it's genuinely unmet
	            // and not already visited.
	            if (!array_contains(visitedKeys, key)) {
	                array_push(queue, key);
	                array_push(visitedKeys, key);
	                unmetConditions[$ key] = true; // Mark as unmet
	            }
	        }
	    }

	    while (array_length(queue) > 0)
	    {
	        var currentKey = array_shift(queue); // Dequeue the first item

	        var producingActs = conditionGraph[$ currentKey];
	        if (producingActs != undefined)
	        {
	            for (var j = 0; j < array_length(producingActs); j++)
	            {
	                var actName = producingActs[j];
	                var action = allActions[$ actName];
	                if (action != undefined && action.conditions != undefined)
	                {
	                    var actionConditionsKeys = struct_get_names(action.conditions);
	                    for (var k = 0; k < array_length(actionConditionsKeys); k++)
	                    {
	                        var conditionKey = actionConditionsKeys[k];

	                        // Check if this condition is unmet and not yet visited
	                        if (!keyMatches(_state, action.conditions, conditionKey))
	                        {
	                            if (!array_contains(visitedKeys, conditionKey))
	                            {
	                                array_push(queue, conditionKey);
	                                array_push(visitedKeys, conditionKey);
	                                unmetConditions[$ conditionKey] = true; // Mark as unmet
	                            }
	                        }
	                    }
	                }
	            }
	        }
	    }

	    // Convert the unmetConditions object keys into an array
	    var resultKeys = struct_get_names(unmetConditions);
	    var out = [];

	    // Filter to ensure only truly unmet conditions from the original state are included
	    for (var i = 0; i < array_length(resultKeys); i++) {
	        var key = resultKeys[i];
	        if (!keyMatches(_state, _conditions, key)) {
	            array_push(out, key);
	        }
	    }

	    return out;
	}

	
	
	
	trimActionsToUnmet = function(relevantActions, unmetKeys)
	{
		var actionSet = {};
	
		// For each unmet condition key, look up actions that can produce it
		for (var i = 0; i < array_length(unmetKeys); i++)
		{
			var key = unmetKeys[i];
		
			if (reactionGraph[$ key] != undefined)
			{
				var producers = reactionGraph[$ key];
			
				for (var j = 0; j < array_length(producers); j++)
				{
					var act = producers[j];
					struct_set(actionSet, act, act);
				}
			}
		}
	
		// Only include relevant actions that appear in the producer set
		var trimmed = [];
		for (var i = 0; i < array_length(relevantActions); i++)
		{
			var actName = relevantActions[i];
			if (struct_exists(actionSet, actName))
			{
				array_push(trimmed, actName);
			}
		}
		
		show_debug_message($"Trimmed to {array_length(trimmed)} <- from: {array_length(relevantActions)}, Relevant actions: {trimmed}");
		return trimmed;
	}



	state_meets_goal = function(sim_state, goal_state)
	{
	    var _goal_keys = struct_get_names(goal_state);
	    for (var i = 0; i < array_length(_goal_keys); i++)
		{
	        var _key = _goal_keys[i];
	        if (!keyMatches(sim_state, goal_state, _key))
			{
	            return false; // Early exit if any condition fails
	        }
	    }
	    return true; // All conditions passed
	}


	
	ancestorHasState = function(node, new_state)
	{
	    var new_key = hashState(new_state);
		//show_debug_message("----------------------------------");
	    while (node != undefined && node != noone)
	    {
	        var node_key = hashState(node.state);
			
			//show_debug_message($"New Key: {new_key}");
			//show_debug_message($"Node Key: {node_key}");
			
	        if (node_key == new_key)
	        {
	            return true;
	        }
	        node = node.parent;
	    }

	    return false;
	}
	
	
	
	// Reconstructs the plan from the goal node by walking back through parents
	reconstructPlan = function(_node)
	{
		var plan = [];
		while (_node.parent != undefined)
		{
			array_insert(plan, 0, _node.action); // insert action at beginning
			_node = _node.parent;
		}
		return plan;
	}

	
	
	getAverageActionCost = function()
	{
	    var _actions = structToArray(allActions);
	    var _count = array_length(_actions);

	    if (_count == 0) return 0; // Avoid divide by zero

	    var _totalCost = 0;
	    for (var i = 0; i < _count; i++)
	    {
	        var _act = _actions[i];
	        _totalCost += _act.cost;
	    }

	    var _avg = _totalCost / _count;
	    //show_debug_message("Average action cost: " + string(_avg));

	    return _avg;
	}



	/// @description Calculates and stores the minimum cost per unit for numerical keys and minimum cost to achieve specific states for direct keys, using the reactionGraph.
	calculateMinActionCostsHeuristicData = function()
	{
	    var MinCostPerKey = {};      // Stores { "key_name": min_cost_per_key_value, ... }
	    var MinCostToAchieve = {};   // Stores { "key_name": { "target_value_string": min_cost, ... }, ... }


	    var _reactionKeys = struct_get_names(reactionGraph);

	    for (var i = 0; i < array_length(_reactionKeys); i++)
	    {
	        var _reactionKey = _reactionKeys[i]; // e.g., "Ammo", "HasWeapon", "Scrap"
	        var _affectingActionNames = reactionGraph[$ _reactionKey]; // Array of action names that react to this key

	        for (var j = 0; j < array_length(_affectingActionNames); j++)
	        {
	            var action_name = _affectingActionNames[j];
	            var _action = allActions[$ action_name]; // Get the full action definition
	            var _action_cost = _action.cost;

	            // Now, examine the specific reaction for this action and key
	            var _reactionEffect = _action.reactions[$ _reactionKey];
				
				if is_undefined(_reactionEffect) continue;
				
				
				// --- Logic for Populating Heuristic Tables ---
            
	            // 1. Populate MinCostPerKey (for numerical quantities that are NOT booleans 0/1)
	            // This is for resources like "Ammo", "Scrap", "Wood" where you want a cost per incremental unit.
	            // Exclude 0 and 1 as they typically represent boolean true/false states in your system.
	            if (is_numeric(_reactionEffect) && _reactionEffect != 0 && _reactionEffect != 1)
	            {
	                var cost_per_unit = _action_cost / abs(_reactionEffect); // Cost per unit of magnitude change
                
	                // Update MinCostPerKey for this key if this action is cheaper per unit
	                if (!struct_exists(MinCostPerKey, _reactionKey) || cost_per_unit < MinCostPerKey[$ _reactionKey])
	                {
	                    MinCostPerKey[$ _reactionKey] = cost_per_unit;
	                }
	            }
            
	            // 2. Populate MinCostToAchieve (for all specific target states: booleans, strings, and exact numbers)
	            // This is for states like "HasWeapon: true", "Location: Town", "Ammo: 0", "Health: 100".
	            // All values (numbers, booleans, strings) are converted to strings for consistent lookup keys.
	            var target_value_str = string(_reactionEffect); // Convert to string for keying

	            if (!struct_exists(MinCostToAchieve, _reactionKey))
	            {
	                MinCostToAchieve[$ _reactionKey] = {};
	            }
	            // If this is the first time we've seen this target value for this key, or if this action is cheaper
	            if (!struct_exists(MinCostToAchieve[$ _reactionKey], target_value_str) || _action_cost < MinCostToAchieve[$ _reactionKey][$ target_value_str])
	            {
	                MinCostToAchieve[$ _reactionKey][$ target_value_str] = _action_cost;
	            }


	        }
	    }
		
		

	    // Optional: Log the results for debugging
	    show_debug_message("Calculated Min Heuristic Costs:");
	    show_debug_message(" ~ MinCostPerKey: " + string(MinCostPerKey));
	    show_debug_message(" ~ MinCostToAchieve: " + string(MinCostToAchieve));
		
		return {
			MinCostPerKey: MinCostPerKey,
			MinCostToAchieve: MinCostToAchieve,
		}
	}
	
	
	
	goalHeuristic = function(_currentState, _goalState)
	{
	    var _totalHeuristicCost = 0;
	    var _unmetConditions = getUnmetConditionsIterative(_goalState, _currentState); 
		var _minCostPerKey = actionCostData.MinCostPerKey;
		var _minCostToAchieve = actionCostData.MinCostToAchieve;

	    var _avg_cost = getAverageActionCost(); // Still a useful fallback

	    for (var i = 0; i < array_length(_unmetConditions); i++)
	    {
	        var _key = _unmetConditions[i];

        
	        var _goalDefinition = _goalState[$ _key]; 

	        // --- NEW/UPDATED LOGIC: Handle missing keys using calculated heuristic data ---
	        if (!struct_exists(_currentState, _key))
	        {
	            var cost_for_missing_key = _avg_cost * 2; // Default fallback if no specific data is found

	            if (is_struct(_goalDefinition)) // It's a numerical comparison goal (e.g., {comparison:">=", value:10})
	            {
	                // Estimate the cost to get to the required amount from zero, using cost_per_unit
	                var needed_amount = _goalDefinition.value;
                
	                // Use global.GOAP_MinCostPerUnit_Data if available, otherwise fallback to average
	                var cost_per_unit = struct_exists(_minCostPerKey, _key) ? _minCostPerKey[$ _key] : _avg_cost;
                
	                cost_for_missing_key = needed_amount * cost_per_unit;
	                if (cost_for_missing_key <= 0) cost_for_missing_key = _avg_cost; // Ensure minimum if goal value is 0 or less
	            }
	            else // It's a simple boolean/value goal (e.g., true, "item_name", or 0/1)
	            {
	                var target_value_str = string(_goalDefinition);
                
	                // Use global.GOAP_MinCostToAchieve_Data for direct lookup
	                if (struct_exists(_minCostToAchieve, _key) && struct_exists(_minCostToAchieve[$ _key], target_value_str))
	                {
	                    cost_for_missing_key = _minCostToAchieve[$ _key][target_value_str];
	                }
	            }
            
	            _totalHeuristicCost += cost_for_missing_key;
	            continue; // Move to the next unmet condition
	        }

	        // --- Existing logic for keys that exist but don't meet the goal ---
	        var _currentValue = _currentState[$ _key];

	        // Now, use the getConditionGap function, which will also be updated to use the new data
	        // We'll pass the global heuristic data to getConditionGap
	        var _val = getConditionGap(_currentValue, _goalDefinition, _key);
	        _totalHeuristicCost += _val;
	    }

	    return _totalHeuristicCost;
	}
	
	
	getConditionGap = function(_state_value, _target_condition_value, _key_name = "unknown_key")
	{
	    var _avg_cost = getAverageActionCost(); // Still a useful fallback
		var _minCostPerKey = actionCostData.MinCostPerKey;
		var _minCostToAchieve = actionCostData.MinCostToAchieve;
		
	    // --- Handle Numerical Conditions (e.g., Ammo >= 100) ---
	    if (is_struct(_target_condition_value)) // Indicates a numerical comparison (e.g., {comparison:">=", value:10})
	    {
	        var operator = _target_condition_value.comparison;
	        var target_numeric_value = _target_condition_value.value;

	        if (!is_numeric(_state_value))
	        {
	            // If the current state value isn't numeric but the goal expects a numeric comparison,
	            // it's an impossible gap for this path (or a very high cost).
	            return infinity;
	        }

	        // Use global.GOAP_MinCostPerUnit_Data for numerical quantities
	        var cost_per_unit = _avg_cost; // Default fallback
	        if (struct_exists(_minCostPerKey, _key_name))
	        {
	            cost_per_unit = _minCostPerKey[$ _key_name];
	        }
	        if (cost_per_unit <= 0) cost_per_unit = _avg_cost; // Defensive: ensure non-zero/positive cost

	        switch (operator)
	        {
	            case ">=":
	                var needed = max(0, target_numeric_value - _state_value);
	                return needed * cost_per_unit;

	            case "<=":
	                var excess = max(0, _state_value - target_numeric_value);
	                return excess * cost_per_unit;

	            case ">":
	                return max(0, (target_numeric_value - _state_value) + 1) * cost_per_unit;

	            case "<":
	                return max(0, (_state_value - target_numeric_value) + 1) * cost_per_unit;

	            case "=":
	                return (_state_value == target_numeric_value) ? 0 : abs(_state_value - target_numeric_value) * cost_per_unit;

	            default:
	                planLog.logWarning($"getConditionGap: Unknown comparison operator '{operator}' for key '{_key_name}'.");
	                return infinity;
	        }
	    }
	    // --- Handle Simple Boolean/Value Conditions (e.g., HasWeapon: true, Location: "Town") ---
	    else // target_condition_value is a direct value (e.g., true/false, "item_name", 0/1)
	    {
	        var target_simple_value = _target_condition_value;

	        if (_state_value == target_simple_value)
	        {
	            return 0; // Condition already met
	        }
	        else
	        {
	            // Use global.GOAP_MinCostToAchieve_Data for specific target values
	            var min_cost_for_value = _avg_cost; // Fallback to average cost
	            var target_value_str = string(target_simple_value); // Convert to string for lookup

	            if (struct_exists(_minCostToAchieve, _key_name))
	            {
	                if (struct_exists(_minCostToAchieve[$ _key_name], target_value_str))
	                {
	                    min_cost_for_value = _minCostToAchieve[$ _key_name][$target_value_str];
	                }
	            }
	            return min_cost_for_value;
	        }
	    }
	}
	
	
	
	collectRelevantActions = function(_conditionsToMeet)
	{
	    // Use a struct to track all unique actions encountered during the traversal.
	    // The keys of this struct will be the unique action names.
	    var _collectedActions = {};

	    // Use an array to simulate a queue for conditions that we need to find actions for.
	    var _conditionsQueue = [];

	    // Initialize the queue with the starting conditions that need to be met.
	    for (var i = 0; i < array_length(_conditionsToMeet); i++)
	    {
	        array_push(_conditionsQueue, _conditionsToMeet[i]);
	    }

	    var head = 0; // This acts as a pointer to the front of our queue

	    // Loop as long as there are conditions in the queue to process
	    while (head < array_length(_conditionsQueue))
	    {
	        var _keyToMeet = _conditionsQueue[head++]; // Dequeue the next condition key

	        // Find actions that *produce* this _keyToMeet (i.e., whose reactions contain this key)
	        if (struct_exists(reactionGraph, _keyToMeet))
	        {
	            var _producingActions = reactionGraph[$ _keyToMeet];

	            // Iterate through each action that can produce this key
	            for (var j = 0; j < array_length(_producingActions); j++)
	            {
	                var _actName = _producingActions[j];

	                // If this action has not already been added to our collected list
	                if (!struct_exists(_collectedActions, _actName))
	                {
	                    struct_set(_collectedActions, _actName, true); // Mark this action as collected (add to struct)

	                    var _act = allActions[$ _actName]; // Get the full action object

	                    // If the action exists and has preconditions
	                    if (_act != undefined && struct_exists(_act, "conditions"))
	                    {
	                        var _actConditionsKeys = struct_get_names(_act.conditions);

	                        // Enqueue all preconditions of this action for further processing
	                        // This ensures we find actions needed for *this action's* conditions
	                        for (var k = 0; k < array_length(_actConditionsKeys); k++)
	                        {
	                            array_push(_conditionsQueue, _actConditionsKeys[k]);
	                        }
	                    }
	                }
	            }
	        }
	    }

	    // After processing all conditions and their related actions,
	    // convert the keys of the _collectedActions struct into a final array to return.
	    return struct_get_names(_collectedActions);
	}



	filterActionsByNegativeEffects = function(_actions, _currentState, _unmetGoalKeys, _goalState)
	{
	    var _filteredActions = [];
	    var _prunedCountThisCall = 0; // Local counter for this function call

	    for (var i = 0; i < array_length(_actions); i++)
	    {
	        var _actName = _actions[i];
	        var _act = allActions[$ _actName];
	        if (_act == undefined) continue;

	        var _hasUndesirableEffect = false;
        
	        for (var j = 0; j < array_length(_unmetGoalKeys); j++)
	        {
	            var _unmetKey = _unmetGoalKeys[j];
            
	            if (!struct_exists(_act.reactions, _unmetKey)) continue;

	            var _reactionValue = _act.reactions[$ _unmetKey];
	            var _currentValue = _currentState[$ _unmetKey];
            
	            var _goalDefinition = undefined;
	            if (struct_exists(_goalState, _unmetKey)) {
	                _goalDefinition = _goalState[$ _unmetKey];
	            } else {
	                continue; 
	            }

	            // Numerical Goals (e.g., Ammo: {comparison: ">=", value: 10})
	            if (is_struct(_goalDefinition) && struct_exists(_goalDefinition, "comparison") && is_numeric(_reactionValue))
	            {
	                var _operator = _goalDefinition.comparison;
	                var _targetValue = _goalDefinition.value;

	                switch (_operator)
	                {
	                    case ">=": 
	                        if (_reactionValue < 0) {
	                            _hasUndesirableEffect = true;
	                        }
	                        break;

	                    case "<=": 
	                        if (_reactionValue > 0) {
	                            _hasUndesirableEffect = true;
	                        }
	                        break;

	                    case ">": 
	                        if (_reactionValue <= 0) {
	                            _hasUndesirableEffect = true;
	                        }
	                        break;

	                    case "<": 
	                        if (_reactionValue >= 0) {
	                            _hasUndesirableEffect = true;
	                        }
	                        break;

	                    case "=": 
	                        if (_reactionValue != 0) {
	                            var _newValue = _currentValue + _reactionValue;
	                            if ((_currentValue == _targetValue && _newValue != _targetValue) ||
	                                (abs(_newValue - _targetValue) > abs(_currentValue - _targetValue)))
	                            {
	                                _hasUndesirableEffect = true;
	                            }
	                        }
	                        break;
	                }
	            }
	            // Boolean/Enum/Direct Value Goals (e.g., HasWeapon: true, Status: "idle")
	            else if (!is_struct(_goalDefinition)) 
	            {
	                if (_goalDefinition != _reactionValue) {
	                    _hasUndesirableEffect = true;
	                }
	            }

	            if (_hasUndesirableEffect) {
	                break; 
	            }
	        }

	        if (_hasUndesirableEffect) {
	            _prunedCountThisCall++; // Increment local counter
	        } else {
	            array_push(_filteredActions, _actName);
	        }
	    }
    
	    // Return a struct containing both the filtered actions and the count
	    return {
	        filteredActions: _filteredActions,
	        prunedCount: _prunedCountThisCall
	    };
	}


	#endregion
	
	
	function astarNode(_state, _action, _parent, _gCost, _hCost) constructor
	{
		state = _state;
		action = _action;
		parent = _parent;
		gCost = _gCost;
		hCost = _hCost;
		fCost = gCost + hCost;
	}
	
	

	findPlan = function(_startState, _goalState)
	{
		
		/*
			Example:
			
			Sim State: { HasWeapon : 1, Ammo : 10, Scrap : -15, WeaponNeedsRepair : 0, HasSupplyCrate : 0 }
			Goal State: { HasWeapon : 1, Ammo : { comparison : ">=", value : 10 }, WeaponNeedsRepair : 0 }
			Expanding (13): g=35, h=0, f=35
		
		*/
		
		#region	<Init Vars>
		
		var _startMS = current_time;
		
		
		var _relevantActions = getPlanActionNames(structToArray(allActions)); // im Dynamically gonna Prune actions per node ltr
		
		
		show_debug_message($"Init Actions: {_relevantActions}");
		
		// cached data
		var _visitedNodes = {};				// stateHash -> best node
		var _stateActionsMap = {};			// track actions tried on each state (state hash -> struct of action names)
		var _deadEnds = {};
		
		
		var _nonDeterministic = false;		// can lower speed of the planner
		
		var _open = [];
		
		var _bestFSoFar = infinity; // Large initial value
		var _bestGoalNode = noone;
		
		var _expanded = 0;
		var _pruned = 0;
		
		var _finalPlan = [];
		
		
		var _startHash = hashState(_startState);
		var _startNode = new astarNode(_startState, undefined, undefined, 0, goalHeuristic(_startState, _goalState));

		
		struct_set(_visitedNodes, _startHash, _startNode);
		array_push(_open, _startNode);

		
		
		#endregion
		
		show_debug_message($"Goal State: {_goalState}");
		show_debug_message($"Start State: {_startState}");
		
		// add a ds priority queue
		
		// A* Pathfinding from _startState -> _goalState
		while (array_length(_open) > 0)
		{
			
			var _node = _open[0];
			//var _printEvery = (_expanded mod 1 == 0);
			var _printEvery = (true);
			
			// Early termination: if best goal found and next node's fCost is >= best goal fCost, break
		    if (_bestGoalNode != noone && _node.fCost >= _bestFSoFar) break; // no better solution 
			
			
			array_delete(_open, 0, 1);


			var _currentState = _node.state;
			var _currentAction = _node.action;
			var _stateHash = hashState(_currentState);
			
			
			// Before expanding:
			if (struct_exists(_deadEnds, _stateHash))
			{
				show_debug_message("Skip dead end");
			    _pruned++;
			    continue;
			}

			// no-no
			//if !is_undefined(_currentAction)
			//{
			//	if (!checkKeysMatch(_currentAction.conditions, _currentState))
			//	{
			//		if (_printEvery) show_debug_message($"Before Expanding ~ Action ({_actName}) conditions not met.");
					
			//		//show_debug_message($"Action Failed on current state: {_currentAction.name}");
					
			//		_pruned++;
			//		continue;
			//	}
			//}
				

			if (_nonDeterministic) _relevantActions = array_shuffle(_relevantActions);



			// dynamic filtering
			var _unmetGoalKeys = getUnmetConditionsIterative(_goalState, _currentState);
			
			show_debug_message($"Unmet Goal Keys: {_unmetGoalKeys}");
			
			var _collectedActs = collectRelevantActions(_unmetGoalKeys);
			_collectedActs = trimActionsToUnmet(_collectedActs, _unmetGoalKeys);


			var _filterResult = filterActionsByNegativeEffects(_collectedActs, _currentState, _unmetGoalKeys, _goalState);
			_collectedActs = _filterResult.filteredActions; // Get the filtered array
			//_pruned += _filterResult.prunedCount;         // Add to the main _pruned counter
			
			show_debug_message($"Filtered Actions ({array_length(_collectedActs)}): {_collectedActs}");

			// Score and sort actions here:
			
			
			var _foundBetter = false;
			
			
			show_debug_message("[ Expanding Relevant Actions ==========================]");
			
			// Expand all relavant actions
			for (var i = 0; i < array_length(_collectedActs); i++)
			{
				var _actName = _collectedActs[i];
				var _act = allActions[$ _actName];
				if (_act == undefined) continue;

				//show_debug_message($"Trying Action: {_actName}");
				
				#region			--- Pruning Before Simulating State ---
				
				
				if (!checkKeysMatch(_act.conditions, _currentState))
				{
					if (_printEvery) show_debug_message($"Action ({_actName}) conditions not met.");
					
					//show_debug_message($"Action conditons dont match: {_actName}");
					
					_pruned++;
					continue;
				}
				
				#endregion
				
			
				var _simState = simulateReactions(_currentState, _act.reactions);
				var _simHash = hashState(_simState);
				
				
				#region			--- Pruning After Simulating State ---
			
				
				// Check if action already tried on this state
				if (!struct_exists(_stateActionsMap, _simHash))
				{
				    var _newActionSet = {};
				    struct_set(_stateActionsMap, _simHash, _newActionSet);
				}
				
				
				var _actionSet = struct_get(_stateActionsMap, _simHash);
				if (struct_exists(_actionSet, _actName))
				{
				    // This action was already tried on this state, prune it
					if (_printEvery) show_debug_message("This action was already tried on this state");
				    _pruned++;
				    continue;
				}
				
				
				if ancestorHasState(_node, _simState)
				{
					if (_printEvery) show_debug_message("After SIM, Ancestor with same action path.");
					_pruned++;
					continue;
				}
				
				
				
				var _hAfter = goalHeuristic(_simState, _goalState);
				
				// Apply heuristic consistency correction
				var _correctedH = max(_hAfter, _node.hCost - _act.cost);
				
				//var _correctedH = _hAfter;
				
				var _newNode = new astarNode(_simState,_act,_node, (_node.gCost + _act.cost), _correctedH);
				
				
				
				// Early termination: if best goal found and next node's fCost is >= best goal fCost, break
				if (_newNode.fCost >= _bestFSoFar)
				{
					if (_printEvery) show_debug_message($"Pruning: new f={_newNode.fCost} >= best f={_bestFSoFar}");
				    _pruned++;
				    continue;
				}
				
				// Optional: Diagnostic output
				if (_newNode.hCost != _hAfter)
				{
					
					/*
					
						"Hey, this action cost more than you thought
						it would get us closer to the goal,
						so I'm pretending the goal is still a bit further away."
					
					*/
					
				    show_debug_message("Heuristic corrected: " + string(_hAfter) + " -> " + string(_newNode.hCost));
					
				}
				
				
				// agressively prunes,	advise against it
				//if (_newNode.hCost > _node.hCost)
				//{
				//	if (_printEvery) show_debug_message($"Worsened heuristic: {_node.hCost} -> {_newNode.hCost}, skipping");
				//	_pruned++;
				//	continue;
				//}
				
				#endregion
				
				
				
				#region			<Create a new node>
				
				
				// Check if we've visited the node based on the _simHash
				if (struct_exists(_visitedNodes, _simHash))
				{
					//show_debug_message("next hash exists");
					
					var _existingOldNode = _visitedNodes[$ _simHash];
					

					// Skip only if the existing node is strictly better
					if (_existingOldNode.fCost < _newNode.fCost)
					{
						if (_printEvery) show_debug_message("Better or equal node already visited, skipping");
						_pruned++;
						continue;
					}
					
					
					if (_newNode.gCost >= _existingOldNode.gCost)
					{
						if (_printEvery) show_debug_message("likely in a loop");
				        _pruned++;
				        continue;
				    }

					
					
					// If you're here, the new node is better.
					// But the open list still contains the old worse node,
					// Remove old version from open list
					show_debug_message("Find & remove old node");
				    for (var j = 0; j < array_length(_open); j++)
					{
				        var _existing = _open[j];
						
						var _extHash = hashState(_existing.state);
						
						//show_debug_message($"Ext: ({_extHash}) ~ Next: ({_sHash})");
						
				        if (_extHash == _simHash)
						{
				            array_delete(_open, j, 1);
							if (_printEvery) show_debug_message("Old node DELETED.");
				            break;
				        }
				    }
				}
				
				
				struct_set(_actionSet, _actName, true);
				
				
				if (state_meets_goal(_simState, _goalState))
				{
					var _f = _newNode.gCost + _newNode.hCost;

				    if (_f < _bestFSoFar)
				    {
				        _bestFSoFar = _f;
				        _bestGoalNode = _newNode;
				    }
					
					// avoid retrying actions on terminal states.
					struct_set(_actionSet, _actName, true);
				    continue;
				}
				
				#endregion
				
				
				
				// Add node to expand
				struct_set(_visitedNodes, _simHash, _newNode);
				array_push(_open, _newNode);
				_expanded++;
				_foundBetter = true;
				
				//show_debug_message($"Action Made it: {_actName}");
				show_debug_message($"[{current_time-_startMS} ms] Expanding ({_expanded}): g={_newNode.gCost}, h={_newNode.hCost}, f={_newNode.fCost}");
				//show_debug_message("--------------------------------------------------");
				
			}
			
			show_debug_message("[ Finished Expanding Relevant Actions =================]");
			
			if (!_foundBetter && !state_meets_goal(_currentState, _goalState))
			{
			    struct_set(_deadEnds, _stateHash, true);
			}

			
			// Tie-break on fCost, then prefer lower hCost (closer to goal)
			array_sort(_open, function(a, b)
			{
				if (a.fCost == b.fCost)
				{
					//show_debug_message("Tie-Break F Cost.");
					return a.hCost < b.hCost;
				}
				//show_debug_message("NO TIE");

				return a.fCost < b.fCost;
			});
			
		}
		
		
		
		// Goal Found.
		if (_bestGoalNode != noone)
		{
			var _plan = reconstructPlan(_bestGoalNode);
			var _pnames = getPlanActionNames(_plan);
			_finalPlan = _pnames;
			var _pLen = array_length(_finalPlan);
			
		
			
			/*
				Summary of all Node DATA
			
					If Prune Ratio goes up, you’re cutting out more useless nodes early, which is good.
					If Efficiency (expanded/total) increases, you’re expanding a higher portion of relevant nodes, also good.
					If Branching Factor drops, your planner is focusing more tightly on promising paths.
					If Goal Efficiency improves, more of your expansions are actually contributing to the final plan.
			*/
			
			
			var _totalNodes = (_pruned + _expanded);
			var _prunedRatio = (_pruned / _totalNodes);					 //cutting out #% of nodes early.
			var _expansionEfficiency = (_expanded / _totalNodes);		 //confirms about #% of nodes got fully expanded.
			var _branchingFactor = (_expanded / _pLen);					 //for every step in the plan, you explored about # nodes.
			var _goalEfficiency = 1 - ((_expanded - _pLen) / _expanded); //only #% of expanded nodes ended up on the final plan path.

			
			show_debug_message($"Node Data: [Total: {_totalNodes}, Pruned: {_pruned}, Expanded: {_expanded}, Prune Ratio: {_prunedRatio}]");
			show_debug_message($"Node Data: [Efficiency: {_expansionEfficiency}, Branching: {_branchingFactor}, Goal Efficiency: {_goalEfficiency}]");
		}
		
		return _finalPlan;
	}
	
	
	
	createPlan = function(_startState, _goalState)
	{
		
		show_debug_message("Create Plan started...");
		
	    setupActionData(); // find a better place to put this ltr.

		// --- Check Plan Cache ---
		var cache_key = generateCacheKey(_startState, _goalState);
		if (struct_exists(plan_cache, cache_key))
		{
			var cached_plan = struct_get(plan_cache, cache_key);
			planLog.logInfo($"Plan found in cache for state/goal: {cache_key}. Using cached plan.");
			return cached_plan; // Return the cached plan immediately
		}
		
		
		
		//show_debug_message($"Con Graph: {conditionGraph}");
		//show_debug_message($"React Graph: {reactionGraph}");
		
		//show_debug_message($"Condition Graph");
		//var _names = struct_get_names(conditionGraph);
		//for(var i=0; i<array_length(_names); i++)
		//{
		//	var _conName = _names[i];
		//	var _conDependencies = conditionGraph[$ _conName];
			
			
		//	show_debug_message($"Condition {i+1}: {_conName}, {_conDependencies}");
		//}
		
		
		show_debug_message($"Reaction Graph");
		var _rnames = struct_get_names(reactionGraph);
		for(var i=0; i<array_length(_rnames); i++)
		{
			var _reactName = _rnames[i];
			var _reactDependencies = reactionGraph[$ _reactName];
			
			show_debug_message($"Reaction {i+1}: {_reactName}, {_reactDependencies}");
		}
		
		
		/*
		
			well if i do chunking maybe i could score the conditions as well to help
			and also combine each individual parts/conditions of the goals to create semi-complex sub-goals.
			it wont really be complex because it would combine 1 or more conditions that go hand in hand.
			then group them into a sub-goal and then chunking  the plan up would look more realistic
			The plan would be more optimized than doing each condition and stacking them individually
			
			
			Decomposition: Breaking a big goal into smaller, ordered subgoals.
			Master Planner: The high-level orchestrator (createPlan).
			Mini-Planner: The low-level A* searcher (findPlan).
			Simulated World State: A copy of the world state that the Master Planner updates internally as it plans, to ensure each mini-plan starts from the correct hypothetical state.
			Compound Goals: Mini-planner goals that include both the immediate subgoal conditions and critical maintained conditions from the overall plan.
			
			
			The Plan:

			Define Goal Decompositions (Methods):
				Create a global data structure (e.g., global.goalDecompositions struct) that maps high-level goal IDs (strings) to their hierarchical breakdowns.
				Each breakdown (method) should include:
				An overall_goal struct (the full goal findPlan would solve monolithically).
				A subgoals array, where each element is a struct defining a mini-goal (e.g., { key: "Scrap", value: 50, type: "numerical", comparison: ">=", description: "..." }).
				(Optional: preconditions for the method itself, to aid in selection).
		
		*/
		
		// try to chunk up the main plan by a goals conditions?
		
		
		var _finalPlan = findPlan(_startState, _goalState);
		
		
		
		
		
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


