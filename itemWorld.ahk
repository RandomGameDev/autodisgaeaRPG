#Include common.ahk


GrindItemWorldLoop1() {
    global settings
    GrindItemWorld(settings.itemWorldOptions.1)
}

GrindItemWorldSingle1() {
    global settings
    GrindItemWorld(settings.itemWorldOptions.1, true)
}

GrindItemWorld(itemWorldOptions, oneTime := false) {
    global mode, patterns, settings
    SetStatus(A_ThisFunc)
   
    sortDone := false
    doWeapon := itemWorldOptions.targetItemType = "weapon" ? true : false
    
    targetItemSort := itemWorldOptions.targetItemSort
    targetItemSortOrder := itemWorldOptions.targetItemSortOrder
    targetItemSortOrderInverse := targetItemSortOrder = "ascending" ? "descending" : "ascending"
    lootTarget := itemWorldOptions.lootTarget
    bribe := itemWorldOptions.bribe

    switch (itemWorldOptions.targetItemRarity) {
        case "any":
            targetItem := patterns.itemWorld.itemTarget.rarity
        case "common":
            targetItem := patterns.itemWorld.itemTarget.rarity.common
        case "legendary":
            targetItem := patterns.itemWorld.itemTarget.rarity.legendary
        case "rareOrLegendary":
            targetItem := [patterns.itemWorld.itemTarget.rarity.rare, patterns.itemWorld.itemTarget.rarity.legendary]
        case "rare":
            targetItem := patterns.itemWorld.itemTarget.rarity.rare
    }
    
    if (itemWorldOptions.farmLevels) {
        farmTrigger := []
        for k, v in itemWorldOptions.farmLevels {
            farmTrigger.push(patterns.itemWorld.level[v])
        }
    }

    battleOptions := settings.battleOptions.itemWorld
    battleOptions.donePatterns := [patterns.itemWorld.title, patterns.itemWorld.leave, patterns.itemWorld.armor]
    battleOptions.preBattle := Func("ItemWorldPreBattle").Bind(farmTrigger, lootTarget)
    battleOptions.onBattleAction := Func("ItemWorldOnBattleAction").Bind(bribe)

    loopTargets := [patterns.stronghold.gemsIcon, patterns.dimensionGate.background, patterns.itemWorld.title, patterns.itemWorld.leave, patterns.battle.auto]
    Loop {
        result := PollPattern(loopTargets)

        if InStr(result.comment, "stronghold.gemsIcon") {
            FindPattern(patterns.tabs.dimensionGate, { doClick : true })
            sleep 1000
        }
        else if InStr(result.comment, "dimensionGate.background") {
            FindPattern(patterns.dimensionGate.itemWorld, { doClick : true, variancePct : 30 })
            sleep 1000
        }
        else if InStr(result.comment, "itemWorld.title") {
            PollPattern(patterns.itemWorld.armor.disabled, { doClick : true, predicatePattern : patterns.itemWorld.armor.enabled, pollInterval : 2000 })
            if (doWeapon) {
                PollPattern(patterns.itemWorld.weapon.disabled, { doClick : true, predicatePattern : patterns.itemWorld.weapon.enabled, pollInterval : 2000 })
            }
            
            if (!sortDone) {
                PollPattern(patterns.sort.button, { doClick : true, predicatePattern : patterns.sort.title })
                if (FindPattern(patterns["sort"][targetItemSort]["disabled"], { variancePct : 20 }).IsSuccess) {
                    PollPattern(patterns["sort"][targetItemSort]["disabled"], { variancePct : 20, doClick : true, predicatePattern : patterns["sort"][targetItemSort]["enabled"], pollInterval : 2000 })
                    sleep 100
                }
                if (FindPattern(patterns["sort"][targetItemSortOrderInverse]["checked"], { variancePct: 5 }).IsSuccess) {
                    PollPattern(patterns["sort"][targetItemSortOrder]["label"], { variancePct: 5, doClick : true, offsetX : 40, predicatePattern : patterns["sort"][targetItemSortOrder]["checked"], pollInterval : 2000 })
                    sleep 100
                }
                if (FindPattern(patterns["sort"]["prioritizeEquippedItems"]["checked"], { variancePct: 5 }).IsSuccess) {
                    PollPattern(patterns["sort"]["prioritizeEquippedItems"]["checked"], { variancePct: 5, doClick : true, offsetX : 40, predicatePattern : patterns["sort"]["prioritizeEquippedItems"]["unchecked"], pollInterval : 2000 })
                    sleep 100
                }

                PollPattern(patterns.prompt.ok, { doClick : true, predicatePattern : itemWorld.title })
                sortDone := true
            }
            
            sleep 500
            PollPattern(targetItem, { doClick : true, predicatePattern : patterns.itemWorld.go, pollInterval : 2000 })
            PollPattern(patterns.itemWorld.go, { doClick : true, predicatePattern : patterns.battle.start })
            PollPattern(patterns.battle.start, { doClick : true })
            DoItem()
            sleep 2000
            if (oneTime) {
                Break
            }
        }
        else if InStr(result.comment, "battle.auto") {
            DoItem()
            sleep 2000
            if (oneTime) {
                Break
            }
        }
    }

    if (mode) {
        ExitApp
    }
}

GrindItemWorldLoop2() {
    global settings
    GrindItemWorld(settings.itemWorldOptions.2)
}

GrindItemWorldSingle2() {
    global settings
    GrindItemWorld(settings.itemWorldOptions.2, true)
}

ItemWorldPreBattle(farmTrigger, lootTarget) {
    SetStatus("DoItem")
    global patterns, settings

    result := FindPattern(farmTrigger, { variancePct : 1 })

    if (result.IsSuccess) {
        if (!FindPattern([patterns.battle.done, patterns.itemWorld.drop], { variancePct : 15 }).IsSuccess)
        {
            DoItemDrop(lootTarget)
        }
    }
}

;https://lexikos.github.io/v2/docs/objects/Functor.htm
ItemWorldOnBattleAction(bribe, result) {
    global patterns

    IF FindPattern(patterns.prompt.innocentIsAppearing).IsSuccess {
        FindPattern(patterns.prompt.no, { doClick : true })
        sleep 1000
    }

    IF FindPattern(patterns.itemWorld.subdue).IsSuccess
        DoSubdue(bribe)
    Else If (result)
        ClickResult(result)
}

DoItem() {
    SetStatus(A_ThisFunc)
    global patterns, settings

    battleOptions := settings.battleOptions.itemWorld

    Loop {
        DoBattle(battleOptions)

        ;Would rather know how it's getting stuck here but oh well
        if (FindPattern(patterns.itemWorld.title).IsSuccess) {
            Break
        }

        result := PollPattern([patterns.itemWorld.nextLevel, patterns.itemWorld.leave], { predicatePattern: [patterns.itemWorld.title, patterns.battle.auto], doClick : true, doubleCheck : true, doubleCheckDelay : 250, pollInterval : 250, clickPattern : patterns.battle.done })
        if (InStr(result.comment, "itemWorld.leave")) {
            Sleep, 1000
            Break
        }
    }

    FindPattern(patterns.blueStacks.trimMemory, { doClick : true})
}

DoItemDrop(lootTarget) {
    SetStatus(A_ThisFunc, 2)
    global patterns, settings

    battleOptions := settings.battleOptions.itemWorld

    actions := []
    singleTargetActions := []

    ;loop through skill list
    for k, v in battleOptions.skills
    {
        actions.Push(patterns.battle.skills[v])
    }

    for k, v in battleOptions.singleTargetSkills
    {
        singleTargetActions.Push(patterns.battle.skills[v])
    }

    actions.Push(patterns.battle.attack)
    singleTargetActions.Push(patterns.battle.attack)

    if (battleOptions.allyTarget && battleOptions.allyTarget != "None") {
        sleep 500
        allyTarget := patterns.battle.target[battleOptions.allyTarget]
        Loop {
            FindPattern(allyTarget, { doClick : true })
            sleep 500
            result := FindPattern(patterns.battle.target.on, { variancePct : 20 })
        } until (result.IsSuccess)
    }

    Loop {
        count := 0
        Loop {
            FindPattern(patterns.battle.auto.enabled, { doClick : true })

            result := FindPattern([patterns.battle.wave.1over3, patterns.battle.wave.2over3, patterns.battle.wave.3over3])
            if (result.IsSuccess) {
            RegExMatch(result.comment, "(?P<wave>\d)over(?P<numWaves>\d)", matches)
            SetStatus(A_ThisFunc . ": " . matchesWave . "/" .  matchesNumWaves . "(" . count . ")", 2)
                if (InStr(result.comment, "3over3"))
                    Break
            }

            result := FindPattern(patterns.battle.skills.label)
            if (result.IsSuccess) {
                result := FindPattern([patterns.battle.wave.3over3, actions], { variancePct : 5, doClick : true, doubleCheck: true, doubleCheckDelay: 250 })
                if (InStr(result.comment, "3over3")) {
                    Break
                }
            }

            sleep, 250
            
            if (FindPattern([patterns.battle.done, patterns.itemWorld.drop], { variancePct : 15 }).IsSuccess) {
                SetStatus(A_ThisFunc . ": Done", 2)
                Break
            }

            count++
            SetStatus(A_ThisFunc . ": " . matchesWave . "/" .  matchesNumWaves . "(" . count . ")", 2)

            if (mod(count, 250) = 0) {
                Resize(true)
            }
        }

        if (FindPattern([patterns.battle.done, patterns.itemWorld.drop], { variancePct : 15 }).IsSuccess) {
            SetStatus(A_ThisFunc . ": Done", 2)
            Break
        }
        
        ;check 4 times just in case
        loop 4 {
            result := FindPattern(patterns.enemy.target)

            while (!result.IsSuccess) {
                PollPattern(patterns.enemy.A, { variancePct : 15, doClick : true, offsetX : 40, offsetY : -30 })
                sleep 500
                result := FindPattern(patterns.enemy.target)
            }
        }

        count := 0
        loop {
            if (FindPattern(patterns.battle.skills.label.IsSuccess)) {
                result := FindPattern(singleTargetActions)
                if (FindPattern(patterns.enemy.A, { variancePct : 15 }).IsSuccess) {
                    ClickResult(result)
                }
            }
            
            result := FindPattern(patterns.enemy.A, { variancePct : 15, bounds : { x1 : 270, x2 : 330, y1 : 420, y2 : 470 } })
            count++
        } until (count > 8 && !result.IsSuccess && !FindPattern(patterns.enemy.target).IsSuccess)
        
        sleep 1500
        result := FindDrop()

        if (result.IsSuccess && (lootTarget = "any" || InStr(lootTarget, result.type))) {
            Break
        }
        Else {
            GiveUpAndTryAgain(battleOptions)
        }
        sleep 1000
    }
}

GiveUpAndTryAgain(battleOptions) {
    global patterns
    PollPattern(patterns.menu.button, { doClick : true, predicatePattern : patterns.menu.giveUp })
    PollPattern(patterns.menu.giveUp, { doClick : true, predicatePattern : patterns.prompt.yes })
    PollPattern(patterns.prompt.yes, { doClick : true, predicatePattern : patterns.prompt.retry })
    PollPattern(patterns.prompt.retry, { doClick : true })
    PollPattern(patterns.battle.auto)

    if (battleOptions.allyTarget && battleOptions.allyTarget != "None") {
        sleep 500
        allyTarget := patterns.battle.target[battleOptions.allyTarget]
        Loop {
            FindPattern(allyTarget, { doClick : true })
            sleep 500
            result := FindPattern(patterns.battle.target.on, { variancePct : 20 })
        } until (result.IsSuccess)
    }
}

FindDrop() {
    global patterns

    legendResult := FindPattern(patterns.itemWorld.drop, { variancePct : 15, bounds : { x1 : 359, y1 : 51, x2 : 378, y2 : 89 } })
    rareResult := FindPattern(patterns.itemWorld.drop, { variancePct : 15, bounds : { x1 : 291, y1 : 51, x2 : 312, y2 : 89 } })
    anyResult := FindPattern(patterns.itemWorld.drop, { variancePct : 15 })
    
    result := {}

    if (legendResult.IsSuccess) {
        Return { type : "legendary", IsSuccess : true }
    }

    if (rareResult.IsSuccess) {
        Return { type : "rare", IsSuccess : true }
    }
    
    if (anyResult.IsSuccess) {
        Return { type : "any", IsSuccess : true }
    }

    Return { IsSuccess : false }
}

DoSubdue(bribe) {
    global patterns
    
    if (bribe && bribe != "None") {
        PollPattern(patterns.itemWorld.bribe.block, { doClick : true, predicatePattern : patterns.itemWorld.bribe[bribe] })
        PollPattern(patterns.itemWorld.bribe[bribe], { doClick : true })
        PollPattern(patterns.itemWorld.bribe.confirm, { doClick : true, predicatePattern : patterns.itemWorld.subdue })
    }

    PollPattern([patterns.itemWorld.subdue], { doClick : true })
}

