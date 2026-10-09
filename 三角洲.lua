--[[ Project Delta | Admin Alert HUD + Optimized ESP | v5.4 ]]
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- 能力探测
local HAS_MEM = type(memory_read) == "function" and type(memory_write) == "function"

local C_ACCENT_DEFECTO=Color3.fromRGB(195,66,148); local C_TEXT=Color3.fromRGB(240,240,245)
local C_ACCENT=C_ACCENT_DEFECTO
local C_DIM=Color3.fromRGB(120,115,135)
local C_DRAG=Color3.fromRGB(18,17,22); local C_BORDER=Color3.fromRGB(55,50,65)
local C_PANEL_INNER=Color3.fromRGB(22,22,26); local C_STRIPE=Color3.fromRGB(70,70,78)
local C_CORPSE=Color3.fromRGB(180,180,180); local C_CORPSE_NPC=Color3.fromRGB(120,120,120)
local MAP_C_ENEMIGO=Color3.fromRGB(220,50,50)

local FILTRO={Equipment=true,Keychain=true,Map=true,DAGR=true,Lighter=true,Radio=true,
    Pathfinder=true,DV2=true,EstonianBorderMap=true,
    ["Village Key"]=true,["EVAC key"]=true,["EVAC Key"]=true,["Airfield Key"]=true,
    ["Garage Key"]=true,["Fueling Station Key"]=true,["Lighthouse Key"]=true,
    ["W. Shirt"]=true,["W. Pants"]=true}

local CFG_DEFECTO={invEsp=true,mostrarLista=true,miraOn=true,cuerpoEsp=true,mapaOn=true,
    opacidadLista=0.85,opacidadDerecha=0.85,lx=10,ly=340,rx=0,ry=44,
    noRetroceso=false,noSpread=false,predictionAim=false,predictionAimTecla=106,predictionAimModo=0,
    accentR=195,accentG=66,accentB=148,panelStripes=true,
    adminAlert=true,adminScanInterval=3,hudAdmin=true}
local CFG={}; for k,v in pairs(CFG_DEFECTO) do CFG[k]=v end

local function exportarCFG()
    local p={"PD"}
    for k,v in pairs(CFG) do
        if k~="noRetroceso" and k~="noSpread" and k~="predictionAim" then
            local t=type(v)
            if t=="boolean" then p[#p+1]=k..":"..(v and "1" or "0")
            elseif t=="number" then p[#p+1]=k..":"..string.format("%.4g",v) end
        end
    end
    return table.concat(p,"|")
end
local function importarCFG(raw)
    if type(raw)~="string" or raw:sub(1,3)~="PD|" then return false end
    local datos={}
    for par in raw:gmatch("[^|]+") do
        local k,v=par:match("^(%w+):(.+)$")
        if k and v and CFG_DEFECTO[k]~=nil and k~="noRetroceso" and k~="noSpread" and k~="predictionAim" then
            local dt=type(CFG_DEFECTO[k])
            if dt=="boolean" then datos[k]=(v=="1")
            elseif dt=="number" then local n=tonumber(v); if n then datos[k]=n end end
        end
    end
    for k,v in pairs(datos) do CFG[k]=v end
    CFG.noRetroceso=false; CFG.noSpread=false; CFG.predictionAim=false
    return true
end
local function copiarPortapapeles(str) pcall(setclipboard,str) end

local CFG_ARCHIVO="ProjectDelta.cfg"
local function archivoConfigDisponible()
    return type(writefile)=="function" and type(readfile)=="function"
end
local function autoGuardarCFG()
    if not archivoConfigDisponible() then return false end
    return pcall(writefile,CFG_ARCHIVO,exportarCFG())
end
local function autoCargarCFG()
    if not archivoConfigDisponible() then return false end
    if type(isfile)=="function" then
        local ok,e=pcall(isfile,CFG_ARCHIVO); if ok and not e then return false end
    end
    local ok,raw=pcall(readfile,CFG_ARCHIVO)
    if ok and raw then return importarCFG(raw) end
    return false
end
local function esperarUI(timeout)
    local t=0
    while t<timeout do
        if type(UI)=="table" and UI.AddTab then return true end
        task.wait(0.5); t=t+0.5
    end
    return false
end
local function sv(o,v) if o then o.Visible=v end end
local function limitar(v,lo,hi) if v<lo then return lo elseif v>hi then return hi end; return v end
local function enRect(mx,my,rx,ry,rw,rh) return mx>=rx and mx<=rx+rw and my>=ry and my<=ry+rh end
local function tamanoFuente(w) return math.max(9,math.min(20,math.floor(12*(w/185)))) end
local function actualizarAccent()
    CFG.accentR=math.max(0,math.min(255,math.floor(CFG.accentR or CFG_DEFECTO.accentR)))
    CFG.accentG=math.max(0,math.min(255,math.floor(CFG.accentG or CFG_DEFECTO.accentG)))
    CFG.accentB=math.max(0,math.min(255,math.floor(CFG.accentB or CFG_DEFECTO.accentB)))
    C_ACCENT=Color3.fromRGB(CFG.accentR,CFG.accentG,CFG.accentB)
end

local function mkSq(x,y,w,h,col,zi,tr,cr)
    local o=Drawing.new("Square"); o.Filled=true; o.Color=col; o.Transparency=tr or 0
    o.Position=Vector2.new(x,y); o.Size=Vector2.new(w,h); o.ZIndex=zi; o.Visible=false
    pcall(function() o.Corner=cr or 0 end); return o
end
local function mkSqO(x,y,w,h,col,zi,cr)
    local o=Drawing.new("Square"); o.Filled=false; o.Color=col; o.Transparency=0; o.Thickness=1
    o.Position=Vector2.new(x,y); o.Size=Vector2.new(w,h); o.ZIndex=zi; o.Visible=false
    pcall(function() o.Corner=cr or 0 end); return o
end
local function mkTx(x,y,t,col,sz,zi,negrita)
    local o=Drawing.new("Text"); o.Text=t; o.Size=sz; o.Color=col; o.Outline=false; o.Center=false
    o.Font=negrita and Drawing.Fonts.SystemBold or Drawing.Fonts.Monospace
    o.Position=Vector2.new(x,y); o.ZIndex=zi; o.Visible=false; return o
end
local function mkLn(x1,y1,x2,y2,col,tr,zi)
    local o=Drawing.new("Line"); o.From=Vector2.new(x1,y1); o.To=Vector2.new(x2,y2)
    o.Color=col; o.Transparency=tr; o.Thickness=1; o.ZIndex=zi; o.Visible=false; return o
end

-- =========================================================
-- ADMIN ALERT
-- =========================================================
local ADMIN_NAMES={
    ["Adrianos5899"]=true,["Eddiejulianooo78"]=true,["Kyotogojosatoruuu_uuu"]=true,
    ["Hollosi"]=true,["Miklos"]=true,["A_Kowalskich"]=true,["charleh2007"]=true,["maks_maksbetov"]=true}
local ADMIN_VOICE_ID="rbxassetid://111354962457936"
local ADMIN_VOICE_VOL=2
local ADMIN_ALERT_COOLDOWN=20
local ADMIN_ULTIMO_AVISO=0
local ADMIN_LISTA={}
local ADMIN_TIEMPO=0
local ADMIN_TXT=nil
local NOTIF_LISTA={}
local NOTIF_MAX=4

local function adminCrearTxt()
    if ADMIN_TXT then return end
    ADMIN_TXT=Drawing.new("Text"); ADMIN_TXT.Size=28
    ADMIN_TXT.Color=Color3.fromRGB(255,40,40); ADMIN_TXT.Outline=true
    ADMIN_TXT.Center=true; ADMIN_TXT.Font=Drawing.Fonts.SystemBold; ADMIN_TXT.Visible=false
end
local function adminNotif(texto,duracion)
    duracion=duracion or 6
    local item={texto=texto,hasta=os.clock()+duracion,creado=os.clock()}
    table.insert(NOTIF_LISTA,1,item)
    while #NOTIF_LISTA>NOTIF_MAX do
        local o=table.remove(NOTIF_LISTA)
        if o.bg then pcall(function() o.bg:Remove() end) end
        if o.txt then pcall(function() o.txt:Remove() end) end
    end
end
local function adminVoz()
    pcall(function()
        if type(Instance)~="table" or not Instance.new then return end
        local s=Instance.new("Sound"); s.SoundId=ADMIN_VOICE_ID; s.Volume=ADMIN_VOICE_VOL
        s.Parent=game:GetService("SoundService"); s:Play()
        task.delay(15,function() pcall(function() s:Destroy() end) end)
    end)
end
local function adminAlertar(nombres)
    local a=os.clock()
    if a-ADMIN_ULTIMO_AVISO<ADMIN_ALERT_COOLDOWN then return end
    ADMIN_ULTIMO_AVISO=a
    local lista=table.concat(nombres,", ")
    adminNotif("WARNING: Admin in this match ("..lista..") - LEAVE NOW!",6)
    adminVoz()
end

task.spawn(function()
    while true do
        task.wait(CFG.adminScanInterval or 3)
        if not CFG.adminAlert then
            if #ADMIN_LISTA>0 then
                ADMIN_LISTA={}
                if ADMIN_TXT and ADMIN_TXT.Visible then ADMIN_TXT.Visible=false end
            end
        else
            local admins={}
            for _,p in ipairs(Players:GetPlayers()) do
                if (ADMIN_NAMES[p.Name] or (p.DisplayName and ADMIN_NAMES[p.DisplayName])) then
                    table.insert(admins,p.Name)
                end
            end
            ADMIN_LISTA=admins
            if #admins>0 then adminAlertar(admins) end
        end
    end
end)

task.spawn(function()
    adminCrearTxt()
    while true do
        task.wait(0.05)
        if not CFG.adminAlert or #ADMIN_LISTA==0 then
            if ADMIN_TXT and ADMIN_TXT.Visible then ADMIN_TXT.Visible=false end
        else
            local cam=workspace.CurrentCamera
            local vp=cam and cam.ViewportSize
            if vp then
                local cx=vp.X*0.5; local cy=vp.Y*0.22
                ADMIN_TXT.Text="ADMIN IN THIS MATCH: "..table.concat(ADMIN_LISTA,", ")
                ADMIN_TIEMPO=ADMIN_TIEMPO+0.05
                local pul2=(math.sin(ADMIN_TIEMPO*3)+1)*0.5
                ADMIN_TXT.Color=Color3.fromRGB(255,math.floor(30+pul2*80),math.floor(30+pul2*80))
                ADMIN_TXT.Transparency=0.15+(1-pul2)*0.25
                ADMIN_TXT.Position=Vector2.new(cx,cy)
                ADMIN_TXT.Visible=true
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.05)
        local cam=workspace.CurrentCamera
        local vp=cam and cam.ViewportSize
        if vp then
            local ahora=os.clock()
            for i=#NOTIF_LISTA,1,-1 do
                if ahora>NOTIF_LISTA[i].hasta then
                    local it=table.remove(NOTIF_LISTA,i)
                    if it.bg then pcall(function() it.bg:Remove() end) end
                    if it.txt then pcall(function() it.txt:Remove() end) end
                end
            end
            local baseX=vp.X-30; local baseY=vp.Y*0.55
            for i,item in ipairs(NOTIF_LISTA) do
                if not item.txt then
                    item.bg=Drawing.new("Square"); item.bg.Filled=true
                    item.bg.Color=Color3.fromRGB(140,0,0); item.bg.Transparency=0.25
                    item.txt=Drawing.new("Text"); item.txt.Size=16
                    item.txt.Color=Color3.fromRGB(255,255,255); item.txt.Outline=true
                    item.txt.Font=Drawing.Fonts.SystemBold
                end
                local edad=ahora-item.creado; local rest=item.hasta-ahora
                local a=math.min(1,edad*4,rest*2)
                item.txt.Transparency=1-a
                item.bg.Transparency=0.75-(a*0.5)
                item.txt.Text=item.texto
                local w=item.txt.TextBounds.X+20
                local h=24; local y=baseY+(i-1)*(h+6)
                item.bg.Position=Vector2.new(baseX-w-10,y-4); item.bg.Size=Vector2.new(w,h)
                item.bg.Visible=true; item.txt.Position=Vector2.new(baseX-w,y); item.txt.Visible=true
            end
        end
    end
end)

-- =========================================================
-- HUD (左上角管理员数)
-- =========================================================
local HUD_ADMIN=nil
local function hudCrear()
    if HUD_ADMIN then return end
    HUD_ADMIN=Drawing.new("Text"); HUD_ADMIN.Size=20
    HUD_ADMIN.Color=Color3.fromRGB(255,60,60); HUD_ADMIN.Outline=true
    HUD_ADMIN.Center=false; HUD_ADMIN.Font=Drawing.Fonts.SystemBold; HUD_ADMIN.Visible=false
end
task.spawn(function()
    hudCrear()
    while true do
        task.wait(0.15)
        if CFG.hudAdmin then
            HUD_ADMIN.Text="ADMINS: "..#ADMIN_LISTA
            HUD_ADMIN.Position=Vector2.new(15,15)
            HUD_ADMIN.Visible=true
        else
            HUD_ADMIN.Visible=false
        end
    end
end)

-- =========================================================
-- NO RECOIL
-- =========================================================
local NO_RETROCESO_BACKUP={}
local NO_RETROCESO_ACTIVO=false
local function encontrarOffsetValor(instancia,vr,tol)
    if not HAS_MEM then return nil,nil end
    tol=tol or 0.0001
    for o=0,0x300,4 do
        local ok,d=pcall(memory_read,"double",instancia.Address+o)
        if ok and math.abs(d-vr)<tol then return o,"double" end
        local ok2,f=pcall(memory_read,"float",instancia.Address+o)
        if ok2 and math.abs(f-vr)<tol then return o,"float" end
    end
    return nil,nil
end
local function detectarOffset(ruta)
    if not HAS_MEM then return nil,nil end
    local cs={"RecoilPattern","RecoilPattern2","RecoilPatternDisabled","RecoilPattern3","RecoilPatternOLD"}
    for _,nc in ipairs(cs) do
        local c=ruta:FindFirstChild(nc)
        if c then
            for _,h in ipairs(c:GetChildren()) do
                if h.ClassName=="BoolValue" then
                    for _,i in ipairs(h:GetChildren()) do
                        if i.ClassName=="NumberValue" and i.Value~=0 then
                            local o,t=encontrarOffsetValor(i,i.Value)
                            if o then return o,t end
                        end
                    end
                end
            end
        end
    end
    return nil,nil
end
local function aplicarNoRetroceso(ruta)
    if not HAS_MEM then return end
    local od,td=detectarOffset(ruta); if not od then return end
    local cs={"RecoilPattern","RecoilPattern2","RecoilPatternDisabled","RecoilPattern3","RecoilPatternOLD"}
    for _,nc in ipairs(cs) do
        local c=ruta:FindFirstChild(nc)
        if c then
            for _,h in ipairs(c:GetChildren()) do
                if h.ClassName=="BoolValue" then
                    for _,i in ipairs(h:GetChildren()) do
                        if i.ClassName=="NumberValue" then
                            local dir=i.Address+od
                            local k=td..":"..tostring(dir)
                            if not NO_RETROCESO_BACKUP[k] then
                                local ok,v=pcall(memory_read,td,dir)
                                if ok then NO_RETROCESO_BACKUP[k]={tipo=td,direccion=dir,valor=v} end
                            end
                            pcall(memory_write,td,dir,0)
                        end
                    end
                end
            end
        end
    end
end
local function activarNoRetroceso()
    if not HAS_MEM then return false end
    local a=ReplicatedStorage:FindFirstChild("RangedWeapons"); if not a then return false end
    for _,w in ipairs(a:GetChildren()) do pcall(aplicarNoRetroceso,w) end
    NO_RETROCESO_ACTIVO=true
    return true
end
local function desactivarNoRetroceso()
    if not HAS_MEM then return 0,0 end
    local r,f=0,0
    for _,d in pairs(NO_RETROCESO_BACKUP) do
        local ok=pcall(memory_write,d.tipo,d.direccion,d.valor)
        if ok then r=r+1 else f=f+1 end
    end
    NO_RETROCESO_ACTIVO=false; return r,f
end

-- =========================================================
-- NO SPREAD
-- =========================================================
local NS_MUZZLE=nil; local NS_CFRAME=nil; local NS_ARMA=nil; local NS_ULT=0
local function rangedWeapons() return ReplicatedStorage:FindFirstChild("RangedWeapons") end
local function armaExiste(n) local rw=rangedWeapons(); return n and rw and rw:FindFirstChild(n)~=nil end
local function nombreDesdeValor(v)
    if not v then return nil end
    local ok,n=pcall(function() return v.Name end)
    if ok and armaExiste(n) then return n end
    local ok2,iv=pcall(function() return v.Value end)
    if ok2 and iv then
        local ok3,ni=pcall(function() return iv.Name end)
        if ok3 and armaExiste(ni) then return ni end
        if armaExiste(iv) then return iv end
    end
    return nil
end
local function armaEquipada()
    if not LocalPlayer or not LocalPlayer.Character then return nil end
    local h=LocalPlayer.Character:FindFirstChild("Holding")
    local ok1,e=pcall(function() return h and h.Value end)
    local dh=ok1 and nombreDesdeValor(e); if dh then return dh end
    local pf=ReplicatedStorage:FindFirstChild("Players")
    local pd=pf and pf:FindFirstChild(LocalPlayer.Name)
    local st=pd and pd:FindFirstChild("Status")
    local gm=st and st:FindFirstChild("GameplayVariables")
    local et=gm and gm:FindFirstChild("EquippedTool")
    local ok2,se=pcall(function() return et and et.Value end)
    local ds=ok2 and nombreDesdeValor(se); if ds then return ds end
    local rw=rangedWeapons()
    if rw then
        for _,c in ipairs(LocalPlayer.Character:GetChildren()) do
            if rw:FindFirstChild(c.Name) and c:FindFirstChild("AttachmentPoints") then return c.Name end
        end
    end
    return nil
end
local function buscarDesc(root,nombre,lim)
    if not root then return nil end
    local q={root}; local i=1; local r=0
    while q[i] and r<(lim or 260) do
        local o=q[i]; i=i+1; r=r+1
        if o.Name==nombre then return o end
        local ok,hs=pcall(function() return o:GetChildren() end)
        if ok and hs then for _,h in ipairs(hs) do q[#q+1]=h end end
    end
    return nil
end
local function muzzleEnRaiz(root,arma)
    if not root then return nil,false end
    local at=root:FindFirstChild("Attachments")
    local fr=at and at:FindFirstChild("Front")
    local rl=fr and fr:FindFirstChild("MuzzleOffset")
    if rl then return rl,true end
    local e=buscarDesc(root,"MuzzleOffset",260); if e then return e,true end
    local ap=root:FindFirstChild("AttachmentPoints")
    local a=ap and (ap:FindFirstChild("Muzzle") or ap:FindFirstChild("Front"))
    if a then return a,false end
    if arma then local ar=root:FindFirstChild(arma); if ar then return muzzleEnRaiz(ar,nil) end end
    return nil,false
end
local function recapturarNS(f)
    local ahora=os.clock()
    if not f and NS_MUZZLE and NS_MUZZLE.Parent and ahora-NS_ULT<0.25 then return NS_MUZZLE end
    NS_ULT=ahora
    local arma=armaEquipada()
    if arma~=NS_ARMA then NS_MUZZLE=nil; NS_CFRAME=nil; NS_ARMA=arma end
    local cam=workspace.CurrentCamera
    local vm=cam and cam:FindFirstChild("ViewModel")
    local it=vm and vm:FindFirstChild("Item")
    local m,real=muzzleEnRaiz(it,arma)
    if not m then m,real=muzzleEnRaiz(vm,arma) end
    if not m and cam then m,real=muzzleEnRaiz(cam:FindFirstChild(LocalPlayer.Name),arma) end
    if not m and LocalPlayer.Character then m,real=muzzleEnRaiz(arma and LocalPlayer.Character:FindFirstChild(arma),arma) end
    if not m and LocalPlayer.Character then m,real=muzzleEnRaiz(LocalPlayer.Character,arma) end
    NS_MUZZLE=m
    if m and real then
        local ok,cf=pcall(function() return m.CFrame end)
        if ok and cf and (not NS_CFRAME or f) then NS_CFRAME=cf end
    else NS_CFRAME=nil end
    return NS_MUZZLE
end
local function aplicarNS()
    if not CFG.noSpread then return end
    local m=recapturarNS(false)
    if m and NS_CFRAME then pcall(function() m.CFrame=NS_CFRAME end) end
end
local function desactivarNS() NS_MUZZLE=nil; NS_CFRAME=nil; NS_ARMA=nil end

-- =========================================================
-- PREDICTIVE AIM
-- =========================================================
local PK_TOGGLE=false; local PK_ANT=false; local PK_ENV=0
local PK_OBJ=nil; local PK_POS=nil; local PK_T=0; local PK_VEL=Vector3.new(0,0,0)
local PK_SPEED={SVD=940,R700=992,Mosin=885,SKS=715,FAL=900,M4=933,M4A1=933,ADAR=933,
    ADAR15=933,MK23=465,MP5SD=465,MP443=465,PKM=940,AsVal=424,["AS Val"]=424,
    TFZ98S=1015,RPG7=200,["RPG-7"]=200,Saiga=425,Makarov=359,PM=359}
local function velArma(n) return PK_SPEED[n] or 900 end
local function parteObj(c) if not c then return nil end return c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") end
local function parteLocal() local c=LocalPlayer and LocalPlayer.Character; return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head")) end
local function calcVel(nom,p)
    local a=os.clock()
    if PK_OBJ~=nom then PK_OBJ=nom; PK_POS=p.Position; PK_T=a; PK_VEL=Vector3.new(0,0,0); return PK_VEL end
    local dt=a-PK_T
    if dt>=0.025 and PK_POS then
        local d=p.Position-PK_POS; local nv=Vector3.new(d.X/dt,0,d.Z/dt)
        PK_VEL=Vector3.new(PK_VEL.X*0.45+nv.X*0.55,0,PK_VEL.Z*0.45+nv.Z*0.55)
        PK_POS=p.Position; PK_T=a
    end
    return PK_VEL
end
local function mejorObj()
    local cam=workspace.CurrentCamera; local vp=cam and cam.ViewportSize
    if not vp then return nil,nil end
    local cx,cy=vp.X*0.5,vp.Y*0.5
    local camPos = cam.CFrame.Position
    local mo,mp,md=nil,nil,335*335
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local pt=parteObj(p.Character)
            if pt then
                local dist = (pt.Position - camPos).Magnitude
                if dist < 500 then
                    local sp,en=WorldToScreen(pt.Position)
                    if en then
                        local dx,dy=sp.X-cx,sp.Y-cy; local d=dx*dx+dy*dy
                        if d<md then mo=p; mp=pt; md=d end
                    end
                end
            end
        end
    end
    return mo,mp
end
local function predActivo()
    if not CFG.predictionAim then return false end
    local modo=CFG.predictionAimModo or 0
    if modo==2 then return true end
    local t=CFG.predictionAimTecla or 106
    local p=iskeypressed(t)
    if modo==1 then return p end
    if p and not PK_ANT then PK_TOGGLE=not PK_TOGGLE end
    PK_ANT=p
    return PK_TOGGLE
end
local function ejecutarPred()
    if not predActivo() then return end
    if type(mousemoverel)~="function" then return end
    local a=os.clock()
    if a-PK_ENV<0.012 then return end
    local o,pt=mejorObj(); if not o or not pt then return end
    local m=recapturarNS(false)
    local org=(m and m.Position) or (parteLocal() and parteLocal().Position)
    if not org then return end
    local arma=armaEquipada()
    local sps=velArma(arma)/0.28
    local dv=pt.Position-org
    local dist=math.sqrt(dv.X*dv.X+dv.Y*dv.Y+dv.Z*dv.Z)
    local t=dist/sps
    local vel=calcVel(o.Name,pt)
    local G = workspace.Gravity or 196.2
    local drop=(G/0.28)*t*t*0.5
    local pred=pt.Position+Vector3.new(vel.X*t,drop,vel.Z*t)
    local cam=workspace.CurrentCamera; local vp=cam and cam.ViewportSize
    if not vp then return end
    local sp,en=WorldToScreen(pred); if not en then return end
    local dx=(sp.X-vp.X*0.5)*0.24; local dy=(sp.Y-vp.Y*0.5)*0.24
    dx=limitar(dx,-30,30); dy=limitar(dy,-30,30)
    if math.abs(dx)<1.25 then dx=0 end
    if math.abs(dy)<1.25 then dy=0 end
    if dx~=0 or dy~=0 then pcall(mousemoverel,dx,dy); PK_ENV=a end
end

-- =========================================================
-- MAP ESP
-- =========================================================
local MAP_SX=0.133647; local MAP_SY=0.133905
local MAP_OX=933.08; local MAP_OY=556.44
local mapaPuntos={}; local mapaUltPos={}; local mapaUltChar={}
local MAP_C_EXIT=Color3.fromRGB(0,255,128); local mapaExits={}
local function mundoAMapa(wx,wz) return MAP_OX+wx*MAP_SX, MAP_OY+wz*MAP_SY end
local function mapaNuevoPunto(col)
    local o=Drawing.new("Circle"); o.Radius=5; o.Filled=true; o.Color=col
    o.Transparency=1; o.NumSides=12; o.Visible=false; return o
end
local function mapaNuevaEtiqueta(col)
    local o=Drawing.new("Text"); o.Color=col; o.Size=10; o.Outline=true
    o.Center=true; o.Font=Drawing.Fonts.SystemBold; o.Visible=false; return o
end
local function mapaObtenerOCrear(nombre,col)
    if not mapaPuntos[nombre] then mapaPuntos[nombre]={punto=mapaNuevoPunto(col),etiqueta=mapaNuevaEtiqueta(col)} end
    return mapaPuntos[nombre]
end
local function mapaEliminar(nombre)
    if mapaPuntos[nombre] then
        pcall(function() mapaPuntos[nombre].punto:Remove() end)
        pcall(function() mapaPuntos[nombre].etiqueta:Remove() end)
        mapaPuntos[nombre]=nil
    end
    mapaUltPos[nombre]=nil; mapaUltChar[nombre]=nil
end
local function mapaOcultar()
    for _,s in pairs(mapaPuntos) do s.punto.Visible=false; s.etiqueta.Visible=false end
    for _,s in pairs(mapaExits) do s.punto.Visible=false; s.etiqueta.Visible=false end
end
local function mapaCargarExits()
    for _,s in pairs(mapaExits) do pcall(function() s.punto:Remove() end); pcall(function() s.etiqueta:Remove() end) end
    mapaExits={}
    local nc=workspace:FindFirstChild("NoCollision"); if not nc then return end
    local folder=nc:FindFirstChild("ExitLocations"); if not folder then return end
    for _,part in ipairs(folder:GetChildren()) do
        if part:IsA("BasePart") then
            local p=Drawing.new("Circle"); p.Radius=6; p.Filled=true; p.Color=MAP_C_EXIT
            p.Transparency=1; p.NumSides=12; p.Visible=false
            local e=Drawing.new("Text"); e.Color=MAP_C_EXIT; e.Size=10; e.Outline=true
            e.Center=true; e.Font=Drawing.Fonts.SystemBold; e.Visible=false
            local px,py=MAP_OX+part.Position.X*MAP_SX, MAP_OY+part.Position.Z*MAP_SY
            p.Position=Vector2.new(px,py); e.Text="[EXIT]"; e.Position=Vector2.new(px,py-12)
            table.insert(mapaExits,{punto=p,etiqueta=e})
        end
    end
end
local function mapaRaiz(p)
    if not p.Character then return nil end
    local h=p.Character:FindFirstChildOfClass("Humanoid"); if h and h.Health<=0 then return nil end
    return p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Head")
end
task.spawn(function()
    local estaba=false
    while true do
        task.wait(0.15)
        if not LocalPlayer then continue end
        local abierto=iskeypressed(77) and CFG.mapaOn
        if not abierto then
            if estaba then mapaOcultar() end
        else
            if not estaba then pcall(mapaCargarExits) end
            for _,s in pairs(mapaExits) do s.punto.Visible=true; s.etiqueta.Visible=true end
            local actual={}; for _,p in ipairs(Players:GetPlayers()) do actual[p.Name]=p end
            for n in pairs(mapaPuntos) do if not actual[n] then mapaEliminar(n) end end
            for n,p in pairs(actual) do
                if not LocalPlayer then break end
                local esYo=(n==LocalPlayer.Name)
                local col=esYo and C_ACCENT or MAP_C_ENEMIGO
                if p.Character~=mapaUltChar[n] then mapaUltPos[n]=nil; mapaUltChar[n]=p.Character end
                local raiz
                if esYo then local ch=LocalPlayer.Character; raiz=ch and ch:FindFirstChild("HumanoidRootPart")
                else raiz=mapaRaiz(p) end
                local wx,wz
                if raiz then wx,wz=raiz.Position.X,raiz.Position.Z; mapaUltPos[n]={x=wx,z=wz}
                elseif mapaUltPos[n] then wx,wz=mapaUltPos[n].x,mapaUltPos[n].z end
                if wx then
                    local px,py=mundoAMapa(wx,wz); local s=mapaObtenerOCrear(n,col)
                    s.punto.Color=col; s.etiqueta