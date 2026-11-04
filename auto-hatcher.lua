-- Nodi scripts: auto hatcher
local Config = {Delay = 0.0001, BatchSize = 20, RequestTimeout = 15, VerifyTimeout = 6}
local env = getgenv()
local previous = {}
for _,key in ipairs({'PetAutoHatch','PetHatchUI','SelectorAutoHatch','CombinedPetHatcher'}) do
    local old = env[key]
    if type(old)=='table' then
        local active = old.Running==true or old.Busy==true or (tonumber(old.InFlight) or 0)>0
        old.Running=false
        if active then previous[#previous+1]={Ref=old,HasBusyFlag=old.Busy~=nil} end
    end
end
local function previousBusy()
    for _,entry in ipairs(previous) do
        if not entry.HasBusyFlag or entry.Ref.Busy==true or (tonumber(entry.Ref.InFlight) or 0)>0 then return true end
    end
    return false
end
local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local player=Players.LocalPlayer
assert(player,'LocalPlayer unavailable')
local playerGui=player:WaitForChild('PlayerGui',10)
assert(playerGui,'PlayerGui unavailable')
for _,name in ipairs({'PetCatalogSelector','PetHatchSelector','PetHatchGuiTest','PetSelectorPaged','CombinedPetHatcher','NodiScriptsGUI'}) do
    local old=playerGui:FindFirstChild(name)
    if old then old:Destroy() end
end
local state={Running=false,Busy=false,InFlight=0,Closed=false,AutoDelete=false,Egg=nil,KeepByEgg={},Hatched=0,Deleted=0}
env.CombinedPetHatcher=state
local function make(class,props,parent)
    local obj=Instance.new(class)
    for k,v in pairs(props) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local gui=make('ScreenGui',{Name='CombinedPetHatcher',ResetOnSpawn=false,DisplayOrder=1000,Enabled=true},playerGui)
state.Gui=gui
local panel=make('Frame',{Size=UDim2.fromScale(0.94,0.86),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.fromRGB(27,31,44),BorderSizePixel=0},gui)
make('UISizeConstraint',{MaxSize=Vector2.new(520,640)},panel)
local function button(text,x,y,w,h,parent)
    return make('TextButton',{Text=text,Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),BackgroundColor3=Color3.fromRGB(61,88,145),TextColor3=Color3.new(1,1,1),TextSize=14,TextWrapped=true,BorderSizePixel=0},parent or panel)
end
local function label(x,y,w,h)
    return make('TextLabel',{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),BackgroundTransparency=1,TextColor3=Color3.new(1,1,1),TextSize=13,TextWrapped=true},panel)
end
local title=label(0.03,0.005,0.94,0.055)
title.Text='Nodi scripts'
title.TextSize=20
title.Active=true
local subtitle=label(0.03,0.06,0.94,0.045)
subtitle.Text='Loading...'
local eggsTab=button('Eggs',0.03,0.115,0.45,0.06)
local petsTab=button('Pets',0.52,0.115,0.45,0.06)
local content=make('Frame',{Position=UDim2.fromScale(0.03,0.19),Size=UDim2.fromScale(0.94,0.48),BackgroundTransparency=1},panel)
local prevButton=button('Previous',0.03,0.685,0.3,0.06)
local nextButton=button('Next',0.67,0.685,0.3,0.06)
local pageLabel=label(0.34,0.685,0.32,0.06)
local hatchButton=button('Auto Hatch: OFF',0.03,0.76,0.45,0.07)
local deleteButton=button('Auto Delete: OFF',0.52,0.76,0.45,0.07)
local copyButton=button('Copy selection',0.03,0.845,0.94,0.055)
local status=label(0.03,0.91,0.94,0.08)
status.TextSize=12
local report={}
local function say(text)
    text=tostring(text)
    if not state.Closed then status.Text=text end
    print('[Nodi scripts] '..text)
    report[#report+1]=text
    if #report>60 then table.remove(report,1) end
end
local dragging,dragInput,dragStart,panelStart,endConnection
local moveConnection=UIS.InputChanged:Connect(function(input)
    if not dragging or input~=dragInput then return end
    local delta=input.Position-dragStart
    panel.Position=UDim2.new(panelStart.X.Scale,panelStart.X.Offset+delta.X,panelStart.Y.Scale,panelStart.Y.Offset+delta.Y)
end)
title.InputBegan:Connect(function(input)
    local mouse=input.UserInputType==Enum.UserInputType.MouseButton1
    local touch=input.UserInputType==Enum.UserInputType.Touch
    if dragging or not(mouse or touch) then return end
    dragging=true
    dragStart=input.Position
    panelStart=panel.Position
    dragInput=touch and input or nil
    if endConnection then endConnection:Disconnect() end
    endConnection=input.Changed:Connect(function()
        if input.UserInputState==Enum.UserInputState.End or input.UserInputState==Enum.UserInputState.Cancel then
            dragging=false
            dragInput=nil
            if endConnection then endConnection:Disconnect() endConnection=nil end
        end
    end)
end)
title.InputChanged:Connect(function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then dragInput=input end
end)
gui.Destroying:Connect(function()
    state.Closed=true
    state.Running=false
    moveConnection:Disconnect()
    if endConnection then endConnection:Disconnect() end
end)
local function initialize()
    local Catalog,Names={},{}
    local function range(first,count)
        local result={}
        for i=0,count-1 do result[#result+1]=first+i end
        return result
    end
    local function nameGroup(first,text)
        local list=string.split(text,'|')
        for i,name in ipairs(list) do Names[first+i-1]=name end
        return #list
    end
    local tierNames={
        'Cat|Dog|Bunny|Lamb|Orange Cat',
        'Brown Cat|White Cat|White Dog|Mouse|White Bunny',
        'Dalmatian|Bear|Polar Bear|Pig|Panda',
        'Koala|Crocodile|Platypus|Seal|Racoon',
        'Owl|Monkey|Turtle|Bat|Bee',
        'Cheeta|Tiger|Zebra|Ladybug',
        'Watermelon|Yeti|Slime|Dragon',
        'Bomb|Ghost|Cherry Monkey|Demon|Cyclops',
        'Fantasy Dragon|Cherry Bomb|Wavy Zebra|Wavy Cheeta|Wavy Tiger',
        'Lava Zebra|Lava Dalmatian|Lava Turtle|Electric Slime|Electric Ghost|Dominus Messor|Dominus Frigidus|Dominus Empyreus',
        'Zombie|Sherbert|Robot|Lava Watermelon|Wavy Bee|Unicorn',
        'Tank|Reaper|Angel|Fire King|Ice Queen|Immortuos|Mortuus',
        'Alien|Puffer|Wooga|Space Cat|Space Dog|Space Bunny|Space Dragon',
        'Revurse|HeadStack|Space Owl|Space Cyclops|Space Bear|Saturn|Dark Saturn|ZER0|1NE',
        'Candy Cane|Candy Corn|Red Lollipop|Green Lollipop|Green Gummy Bear|Yellow Gummy Bear|Cookie|Rainbow|Dark Candy Corn|Ame Damnee|Domortuus',
        'Cyborg Cat|Cyborg Dog|Computer|Cyborg|Space Ranger|Red Space Ranger|Friendly Cyborg|RoVer|Cyborg Demon|C0RE|C0RE SH0CK|Cyborg Dominus',
        'Dominus Pumpkin|Dominus Cherry|Dominus Noob|Dominus Wavy|Dominus HeadStack|Dominus Damnee|Dominus Rainbow|Dominus Electric|Dominus Huge',
        'Aesthetic Cat|Spike|Magic Fox|Chimera|Hydra|Agony',
    }
    for tier,text in ipairs(tierNames) do
        local first=tier*1000+1
        local count=nameGroup(first,text)
        Catalog[#Catalog+1]={'Tier '..tier,range(first,count)}
    end
    nameGroup(66001,'Zombie Cat|Zombie Dog|Spider|Pumpkin|Skeleton|Ghostdeeri|Sorrow|Willow Wisp|Willow Wisp Green|Skeleton Ghost')
    nameGroup(66101,'Pumpkin Bunny|Candy Bat|Scarecrow Dog|Black Cat|Corn Crow|Tombstone Turtle|Mummy Cat|Coffin Bear|Wolfman|Banshee|Grave Reaper|Potion Slime|Broom Fox|Hex Owl|Cauldron Dragon|Midnight Phoenix|Hallow Dominus|Giant Pumpkin Bunny|Huge Pumpkin')
    nameGroup(66201,'Pumpkin Dog|Ghost Dragon|Candy Corn Unicorn|Phantom Bat|Skeleton Dragon|Vampire Dominus|Giant Vampire Dominus|Huge Spider')
    nameGroup(76001,'Festive Cat|Festive Dog|Festive Bunny|Festive Racoon')
    nameGroup(77001,'Festive Seal|Festive Dragon|Snow Spike|Ice Spike')
    nameGroup(78001,'Festive Ame Damnee|Gingerbread|Reindeer|Festive Dominus|Randolph')
    nameGroup(79001,'Festive Immortuos|Festive C0RE|Giant Penguin')
    nameGroup(88001,'Pog Cat|Pog Dog|Pog Dragon|Pog Immortuus|Giant Pog Cat')
    nameGroup(90002,'Green Snake|Red Snake|Purple Snake|Wavy Snake')
    local special={
        {'Hallow',range(66001,10)},{'Cursed Hallow',range(66005,6)},
        {'Halloween Tier 1',range(66101,5)},{'Halloween Tier 2',range(66106,6)},
        {'Halloween Tier 3',range(66112,6)},{'Halloween Tier 4',range(66115,5)},
        {'Halloween Tier 5',range(66201,6)},{'Halloween Tier 6',range(66204,5)},
        {'Christmas Tier 1',range(76001,4)},{'Christmas Tier 2',range(77001,4)},
        {'Christmas Tier 3',range(78001,5)},{'Christmas Tier 4',{78005,79001,79002,79003}},
        {'Pog',range(88001,5)},{'Snake',range(90002,4)},{'TestEgg',{79003}},
    }
    for _,entry in ipairs(special) do Catalog[#Catalog+1]=entry end
    local preferred={[66206]=true,[66207]=true,[66208]=true}
    for _,entry in ipairs(Catalog) do
        local keep={}
        for _,id in ipairs(entry[2]) do keep[id]=preferred[id]==true end
        state.KeepByEgg[entry[1]]=keep
    end
    local view,page,chosen='Eggs',1,nil
    local perPage=5
    local function locked()
        if state.Busy then say('Stop hatching and wait before changing settings.') return true end
        return false
    end
    local function entries() return view=='Eggs' and Catalog or (chosen and chosen[2] or {}) end
    local render
    render=function()
        if state.Closed then return end
        for _,obj in ipairs(content:GetChildren()) do obj:Destroy() end
        local values=entries()
        local pages=math.max(1,math.ceil(#values/perPage))
        page=math.clamp(page,1,pages)
        pageLabel.Text=page..' / '..pages
        subtitle.Text=view=='Eggs' and ('Eggs: '..#Catalog..' | Batch: '..Config.BatchSize) or (state.Egg or 'Choose an egg first')
        for slot=1,perPage do
            local value=values[(page-1)*perPage+slot]
            if value then
                if view=='Eggs' then
                    local entry=value
                    local b=button(entry[1]..' - '..#entry[2]..' pets',0,(slot-1)*0.2,1,0.18,content)
                    b.Activated:Connect(function()
                        if locked() then return end
                        chosen=entry
                        state.Egg=entry[1]
                        view,page='Pets',1
                        render()
                    end)
                else
                    local id=value
                    local kept=state.KeepByEgg[state.Egg][id]
                    local b=button((kept and 'KEEP: ' or 'DELETE: ')..(Names[id] or tostring(id))..' ['..id..']',0,(slot-1)*0.2,1,0.18,content)
                    b.BackgroundColor3=kept and Color3.fromRGB(35,117,78) or Color3.fromRGB(112,53,65)
                    b.Activated:Connect(function()
                        if locked() then return end
                        local keep=state.KeepByEgg[state.Egg]
                        keep[id]=not keep[id]
                        render()
                    end)
                end
            end
        end
        if view=='Pets' and not chosen then button('Select an egg in Eggs first',0,0,1,0.18,content) end
    end
    eggsTab.Activated:Connect(function() view,page='Eggs',1 render() end)
    petsTab.Activated:Connect(function() view,page='Pets',1 render() end)
    prevButton.Activated:Connect(function() page=math.max(1,page-1) render() end)
    nextButton.Activated:Connect(function() page=math.min(math.max(1,math.ceil(#entries()/perPage)),page+1) render() end)
    copyButton.Activated:Connect(function()
        if not state.Egg then say('Select an egg first.') return end
        local ids={}
        for id,keep in pairs(state.KeepByEgg[state.Egg]) do if keep then ids[#ids+1]=id end end
        table.sort(ids)
        local lines={'Egg = '..string.format('%q',state.Egg)..',','KeepPetIDs = {'}
        for _,id in ipairs(ids) do lines[#lines+1]='    '..id..',' end
        lines[#lines+1]='},'
        local clipboard=setclipboard or toclipboard
        if type(clipboard)=='function' then
            local ok=pcall(clipboard,table.concat(lines,'\n'))
            say(ok and 'Selection copied.' or 'Clipboard failed.')
        else print(table.concat(lines,'\n')) say('Selection printed to console.') end
    end)
    local function required(parent,name)
        local obj=parent:FindFirstChild(name)
        assert(obj,'Missing '..parent:GetFullName()..'.'..name)
        return obj
    end
    local function request(remote,...)
        assert(remote:IsA('RemoteFunction'),'Unexpected remote type')
        local args=table.pack(...)
        local done,result=false,nil
        state.InFlight=state.InFlight+1
        task.spawn(function()
            result=table.pack(pcall(function() return remote:InvokeServer(table.unpack(args,1,args.n)) end))
            state.InFlight=state.InFlight-1
            done=true
        end)
        local deadline=os.clock()+Config.RequestTimeout
        while not done and os.clock()<deadline do task.wait(0.05) end
        assert(done,'Request timed out; sent request may still complete')
        assert(result[1],tostring(result[2]))
        local values={n=result.n-1}
        for i=2,result.n do values[i-1]=result[i] end
        return values
    end
    local function snapshot(save)
        assert(type(save.Pets)=='table','Unexpected inventory format')
        local owned,count={},0
        for _,pet in pairs(save.Pets) do
            assert(type(pet)=='table' and pet.id~=nil,'Invalid pet record')
            owned[tostring(pet.id)]=pet
            count=count+1
        end
        return owned,count
    end
    local function extract(response)
        local pets,seen,ids={},{},{}
        local function walk(value,depth)
            if type(value)~='table' or seen[value] or depth>12 then return end
            seen[value]=true
            if value.id~=nil and value.n~=nil then
                local uid=tostring(value.id)
                if not ids[uid] then ids[uid]=true pets[#pets+1]=value end
                return
            end
            for _,child in pairs(value) do if type(child)=='table' then walk(child,depth+1) end end
        end
        walk(response,0)
        return pets
    end
    local function run(egg,keep,autoDelete,allowed)
        local remotes=required(workspace,'__REMOTES')
        local core=required(remotes,'Core')
        local gameRemotes=required(remotes,'Game')
        local statsRemote=required(core,'Get Other Stats')
        local shop=required(gameRemotes,'Shop')
        local inventory=required(gameRemotes,'Inventory')
        local function getSave()
            local result=request(statsRemote)
            local all=result[1]
            local stats=type(all)=='table' and all[player.Name]
            assert(type(stats)=='table' and type(stats.Save)=='table','Unexpected stats response')
            return stats.Save
        end
        while state.Running do
            local save=getSave()
            local before,count=snapshot(save)
            local slots=tonumber(save.PetSlots)
            assert(slots,'PetSlots missing')
            assert(count<slots,'Inventory full; existing pets preserved')
            if not state.Running then return end
            local batchSize=math.min(Config.BatchSize,math.max(0,math.floor(slots-count)))
            assert(batchSize>0,'No free pet slots')
            say('Requesting '..batchSize..' hatches: '..egg)
            local completed=0
            local responses,failures={},{}
            for index=1,batchSize do
                local requestIndex=index
                task.spawn(function()
                    local ok,result=pcall(function()
                        if not state.Running then return nil end
                        return request(shop,'Buy','Eggs',egg)
                    end)
                    if not ok then failures[requestIndex]=tostring(result)
                    elseif result then
                        if result[1]==false then failures[requestIndex]='Purchase rejected: '..tostring(result[2])
                        else responses[requestIndex]=result end
                    end
                    completed=completed+1
                end)
            end
            while completed<batchSize do task.wait() end
            if not state.Running then return end
            local pets,seenIDs={},{}
            for index=1,batchSize do
                local response=responses[index]
                if response then
                    local returned=extract(response)
                    if #returned==0 then failures[index]='Unrecognized hatch response'
                    else
                        for _,pet in ipairs(returned) do
                            local uid=tostring(pet.id)
                            if not seenIDs[uid] then seenIDs[uid]=true pets[#pets+1]=pet end
                        end
                    end
                end
            end
            local failureCount,firstFailure=0,nil
            for index=1,batchSize do
                if failures[index] then
                    failureCount=failureCount+1
                    firstFailure=firstFailure or failures[index]
                    warn('[Nodi scripts] '..failures[index])
                end
            end
            assert(failureCount==0,'Batch stopped: '..failureCount..' request(s) failed. Successful hatches preserved. '..tostring(firstFailure))
            assert(#pets>0,'No recognizable hatch results')
            local after,confirmed
            local deadline=os.clock()+Config.VerifyTimeout
            repeat
                if not state.Running then return end
                after=snapshot(getSave())
                confirmed=true
                for _,pet in ipairs(pets) do
                    local uid=tostring(pet.id)
                    local current=after[uid]
                    if before[uid] or not current or tostring(current.n)~=tostring(pet.n) then confirmed=false break end
                end
                if not confirmed then task.wait(0.2) end
            until confirmed or os.clock()>=deadline
            assert(confirmed,'Hatches unconfirmed; no deletion performed')
            if not state.Running then return end
            local deleteIds={}
            for _,pet in ipairs(pets) do
                local id=tonumber(pet.n)
                state.Hatched=state.Hatched+1
                if autoDelete and id and allowed[id] and not keep[id] then deleteIds[#deleteIds+1]=after[tostring(pet.id)].id end
            end
            if state.Running and #deleteIds>0 then
                local deletion=request(inventory,'MultiDelete',deleteIds)
                assert(deletion[1]~=false,'Deletion rejected')
                local removed=false
                local verifyDeadline=os.clock()+Config.VerifyTimeout
                repeat
                    local remaining=snapshot(getSave())
                    removed=true
                    for _,uid in ipairs(deleteIds) do if remaining[tostring(uid)] then removed=false break end end
                    if not removed then task.wait(0.2) end
                until removed or os.clock()>=verifyDeadline
                assert(removed,'Deletion unconfirmed; stopping purchases')
                state.Deleted=state.Deleted+#deleteIds
            end
            say(egg..' | Hatched: '..state.Hatched..' | Deleted: '..state.Deleted)
            task.wait(Config.Delay)
        end
    end
    deleteButton.Activated:Connect(function()
        if locked() then return end
        state.AutoDelete=not state.AutoDelete
        deleteButton.Text='Auto Delete: '..(state.AutoDelete and 'ON' or 'OFF')
        deleteButton.BackgroundColor3=state.AutoDelete and Color3.fromRGB(135,55,65) or Color3.fromRGB(61,88,145)
        say(state.AutoDelete and 'DELETE-marked new hatches will be deleted.' or 'All new hatches will be kept.')
    end)
    hatchButton.Activated:Connect(function()
        if state.Busy then
            state.Running=false
            hatchButton.Text='Stopping...'
            say('Sent purchase requests may still finish.')
            return
        end
        if previousBusy() or state.InFlight>0 then say('Older requests pending. Wait, or rejoin before restarting.') return end
        if not chosen or not state.Egg then say('Select an egg first.') return end
        local egg=state.Egg
        local keep,allowed={},{}
        for _,id in ipairs(chosen[2]) do allowed[id]=true end
        for id,selected in pairs(state.KeepByEgg[egg]) do if selected then keep[id]=true end end
        if state.AutoDelete and not next(keep) then say('Mark at least one pet KEEP before enabling deletion.') return end
        local autoDelete=state.AutoDelete
        state.Running=true
        state.Busy=true
        hatchButton.Text='Auto Hatch: ON'
        hatchButton.BackgroundColor3=Color3.fromRGB(35,117,78)
        task.spawn(function()
            local ok,err=pcall(run,egg,keep,autoDelete,allowed)
            state.Running=false
            state.Busy=false
            if not state.Closed then
                hatchButton.Text='Auto Hatch: OFF'
                hatchButton.BackgroundColor3=Color3.fromRGB(61,88,145)
            end
            if not ok then
                say('Stopped: '..tostring(err))
                local clipboard=setclipboard or toclipboard
                if type(clipboard)=='function' then pcall(clipboard,table.concat(report,'\n')) end
            else say('Stopped | Hatched: '..state.Hatched..' | Deleted: '..state.Deleted) end
        end)
    end)
    render()
    say('Choose an egg and KEEP pets. Up to 20 purchases per batch.')
end
local ok,err=pcall(initialize)
if not ok then say('Setup error: '..tostring(err)) end
