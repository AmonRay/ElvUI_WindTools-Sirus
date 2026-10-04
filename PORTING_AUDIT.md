# WindTools — WoW 3.3.5a backport audit

Дата аудита: 2026-08-27

## Выполнено в текущем срезе

- Добавлен `Preflight.lua`, загружаемый до библиотек и `Initialize.lua`; он только собирает capability report и не мутирует глобальные Blizzard namespace.
- Добавлен централизованный `Core/CompatibilityLayer.lua`.
- Реализованы legacy fallback для addon, item, container, spell, CVar, chat, invite, reload и quest API.
- Добавлены capability flags, отличающие реальные namespace клиента от placeholder-таблиц.
- Retail-only модули `PreyHunt`, `SuperTracker`, `MythicPlus`, `ObjectiveProgress`, `Icons`, `Progression` не регистрируются без требуемых возможностей.
- Защищены загрузочные инициализаторы в Item, Tooltips, Maps, Quest, Social, Misc, Combat, Skins, UnitFrames и Options.
- `LibObjectiveProgress` и `LibKeystone` получили безопасные fallback для отсутствующих Wrath API.
- `LibKeystone` допускает retail/Wrath-compatible project IDs.
- `EventTracker` не требует `C_Timer.NewTicker`: при отсутствии timer API выполняется безопасный single refresh.
- ElvUI не изменялся.
- Финальный статический проход устранил прямые обращения к отсутствующим namespace в загрузочных локальных привязках; optional callbacks теперь регистрируются только при наличии processor/enum.
- Добавлены capability flags для cinematic и spell activation overlay; соответствующие модули не стартуют на клиенте без подтверждённых объектов.
- Tooltips: load-time регистрация сабмодулей (GroupInfo/HealthBar/ObjectiveProgress/Progression/TierSet) защищена — если `Modules/Tooltips/Core.lua` не исполнился, вместо каскада ошибок `attempt to call method 'AddCallback' (a nil value)` выводится одно диагностическое сообщение о неполной копии файлов.
- Misc/ExitPhaseDiving: модуль был retail-only, но не gated (в отличие от ReshiiWrapsUpgrade/HideCrafter/SkipCutScene) и падал на 3.3.5a (`Texture:EnableMouse` отсутствует). Теперь гейтится по наличию спелла 1250255 (`W.Compatibility.GetSpellInfo`), а `createButton` защищён от legacy-API (`EnableMouse`/`SetColorTexture` fallback, `E:GetAuraByID` guard).
- Fonts: на 3.3.5a FontString без шрифта падает на `SetText()` (`<unnamed>:SetText(): Font not set`) — Wrath-шрифты не имеют дефолта, в отличие от retail. `F.FontTemplate` теперь резолвит `(en)`-вариант LSM-имени и страхует отсутствие шрифта дефолтом `E.media.normFont`; `F.SetFontWithDB` при пустом `db.name` применяет дефолтный шрифт вместо no-op (GameBar time area падал именно так).
- Quest completion: `IsQuestFlaggedCompleted`/`IsQuestFlaggedCompletedOnAccount` отсутствуют (или регистрируются позже) на модифицированном клиенте — EventTracker падал в таймере (`attempt to call upvalue 'C_QuestLog_IsQuestFlaggedCompleted' (a nil value)`, Count 5). Добавлены ленивые crash-proof чекеры `Compatibility.IsQuestFlaggedCompleted(OnAccount)` с деградацией в `false`; EventTracker/EventTracker_Data/TurnIn переведены на них.
- ChatText/RemoveExtraSpaces: на Sirus ElvUI 9.05 `E.RemoveExtraSpaces` — colon-метод (`function E:RemoveExtraSpaces(message)`); вызов сырой ссылки с одним аргументом сдвигал message в `self` и `gsub` получал nil (`bad argument #1 to 'gsub' (string expected, got nil)` в ElvUI API.lua:210). Вызов обёрнут с явным `E.RemoveExtraSpaces(E, message)` и деградацией в исходный message при отсутствии метода.
- GameBar: кнопки создаются с `SecureActionButtonTemplate`, но `SetAttribute`/`ClearAttributes`/`GetAttribute` — Cataclysm+ API. Важный нюанс клиента: `SetAttribute` присутствует, а `ClearAttributes` — нет, поэтому каждый метод guardится отдельно (первичный краш был `attempt to call method 'ClearAttributes' (a nil value)` в UpdateButton). На retail путь атрибутов без изменений; при отсутствии `SetAttribute` кнопки получают обычный `OnClick` (макро через `RunMacroText`, hearthstone-макросы сохраняются в `button.hearthstoneMacro<side>`, item через `UseItemByName`, click через те же `config.click`-функции). Дополнительно защищены `PLAYER_REGEN_ENABLED/DISABLED`, `UpdateHouseAttributes` и клик-функции retail-only глобальных (`PlayerSpellsUtil`/`HousingFramesUtil`/`StoreMicroButton`) с Wrath-фолбэками `ToggleSpellBook(BOOKTYPE_SPELL)`/`ToggleTalentFrame`.
- Quest/Progress и Quest/TurnIn: незащищённые capture-привязки `C_QuestLog_GetQuestTagInfo` (Progress.lua:53→167, TurnIn.lua:83→625) падали с `attempt to call upvalue 'C_QuestLog_GetQuestTagInfo' (a nil value)` — на клиенте отсутствует `C_QuestLog.GetQuestTagInfo`. Привязки переведены на `W.Compatibility.GetQuestTagInfo` (call-time accessor). Заодно закрыты два латентных краша того же класса в Progress.lua: `C_ScenarioInfo_GetScenarioStepInfo` (вызов в `FetchAllScenarioProgressData`) и `C_MythicPlus_IsMythicPlusActive` (условие в `ProcessScenarioUpdate`).
- Maps/EventTracker_Data: capture `GetProfessions` без фолбэка падал в тикере (`attempt to call upvalue 'GetProfessions' (a nil value)`, Count 7) — на клиенте глобал не зарегистрирован. `GetProfessions`/`GetProfessionInfo` получили nil-фолбэки (ProfessionsWeeklyMN деградирует в пустой список), `GetServerTime` — фолбэк на `time()` (ротация loopTimer продолжает работать), `C_QuestLog_IsOnQuest` — фолбэк `false`.
- GameBar tooltip: `DT.tooltip:SetOwner(panel.text, ...)` падал на 3.3.5a (`SetOwner(): Wrong object type, expected frame`) — FontString не является валидным owner'ом тултипа на Wrath (в отличие от retail, где SetOwner принимает Region). Вызов обёрнут в pcall с фолбэком на `panel` (фрейм): на retail поведение идентично, на Wrath тултип якорится к панели времени.
- GameBar timers: `self.tooltipTimer:Cancel()` в OnLeave падал с `attempt to index field 'tooltipTimer' (a nil value)` — при ошибке в OnEnter (например, SetOwner) тикер не успевал создаться. Отмены `tooltipTimer` (OnLeave) и `timeAreaUpdateTimer` (UpdateTimeTicker) теперь nil-safe и обнуляются после отмены.
- Item/Inspect: `frame.SpecIcon:SetScript(...)` падал на 3.3.5a (`attempt to call method 'SetScript' (a nil value)`) — `SpecIcon` это Texture, а скрипты есть только у фреймов (в отличие от retail). SetScript-блок обёрнут в `if frame.SpecIcon.SetScript` — тултип спека пропускается на Wrath; единственное место в кодовой базе, где SetScript вешается на текстуру.
- Item/ExtendMerchantPages: модуль менял `MERCHANT_ITEMS_PER_PAGE` на `numberOfPages*10` и создавал слоты `MerchantItem13+` через `CreateFrame(..., "MerchantItemTemplate")` — но клиентский `MerchantFrame_UpdateMerchantInfo` читает `_G["MerchantItem"..i.."ItemButton"]`, и для Lua-созданных слотов эти глобалы не появляются → краш в клиентском коде (`MerchantFrame.lua:244: attempt to index local 'itemButton' (a nil value)`). По распакованному FrameXML клиента (`patch-ruRU-i/DF/Interface`): клиент сам имеет 12 встроенных слотов (`MerchantItem1..12` в MerchantFrame.xml) при `MERCHANT_ITEMS_PER_PAGE=10`. Модуль переписан: страница ограничивается реально существующими слотами (12 на этом клиенте), создание фреймов и хуки раскладки удалены — раскладку 12 слотов клиент делает сам.
- GameBar: `self:SecureHook(_G.GuildMicroButton, "UpdateNotificationIcon", ...)` падал в Initialize (`Usage: SecureHook ... Attempting to hook a non existing target`) — на 3.3.5a у `GuildMicroButton` нет retail-mixin метода `UpdateNotificationIcon` (та же причина, что и у `ClearAttributes`). Хук теперь ставится только при наличии метода; `UpdateGuildButton` всё равно обновляется при profile update.
- Item/AlreadyKnown: те же retail-методы на кнопках торговца — `button:SetItemButtonTextureVertexColor(...)` заменён на Wrath-глобал `SetItemButtonTextureVertexColor(button, ...)` (как уже было в Buyback), а `SecureHook(itemButton, "SetItemButtonTextureVertexColor", ...)` ставится только при наличии метода (на Wrath хука нет, начальная подсветка всё равно применяется через `UpdateMerchantItemButton`).
- Options/Skins: `DoesAddOnExist` — Cataclysm+ глобал, на клиенте отсутствует → `W.Compatibility.DoesAddOnExist` падал в `disabled()` при открытии опций (`attempt to call upvalue 'C_AddOns_DoesAddOnExist' (a nil value)`). В CompatibilityLayer добавлен нативный Wrath-фолбэк через `GetAddOnInfo(name) ~= nil`.
- Specializations: `C_SpecializationInfo` на клиенте существует, но с **пустой таблицей функций** (по APIDocumentation), глобалы `GetSpecialization`/`GetInspectSpecialization`/`GetSpecializationInfoByID` отсутствуют → Item/Inspect падал при открытии персонажа (`attempt to call upvalue 'C_SpecializationInfo_GetSpecialization' (a nil value)`). Реальный API спец реализован форком ElvUI-Sirus на `E.*` (Core/Init.lua: `E.GetSpecialization` → индекс талант-вкладки; `E.GetSpecializationInfo` → id, name, description, icon, background, role). В CompatibilityLayer добавлены accessor'ы `GetSpecialization`/`GetSpecializationInfo`/`GetInspectSpecialization`/`GetSpecializationInfoByID` с call-time резолвингом: retail-методы `C_SpecializationInfo` при наличии, иначе `E.*`-путь Sirus; Sirus-сигнатура нормализована к retail (`background` убран, role остаётся на позиции 5). Inspect/ContextMenu/LFGList переведены с сырых capture-привязок (и `function() return nil end`-фолбэков) на accessor'ы.
- **Skins/ElvUI (тени не применялись вообще)**: корень — `S:ProcessWaitingAceGUIWidgets()` падал на `assert(lib, "AceGUI-3.0 not found")`: AceGUI-3.0 на этом клиенте лежит только в **LoadOnDemand** аддоне `ElvUI_Options`, а на retail — встроен в сам ElvUI. При PLAYER_LOGIN библиотека не зарегистрирована → assert бросал ошибку **внутри `S:Initialize`**, который обёрнут в `xpcall(..., F.Developer.LogDebug)` (молчаливый при logLevel<4) → весь модуль Skins умирал тихо: ни теней, ни скинов, ни ошибок в чате. Assert заменён на безвредный `return` (скининг AceGUI-виджетов всё равно навешивается через `HandleAceGUIWidget` при загрузке опций).
- Skins/ElvUI hook-цели, отсутствующие на этом клиенте (иначе после оживления модуля были бы видимые ошибки и обрыв колбэков): `_G.ZoneAbilityFrame` (глобального фрейма нет — только `ZoneAbilityFramePriority`), `AB.SetupFlyoutButton` (в форке ActionBars нет) и `NP.StylePlate` (Nameplates форка использует другой API) — все три SecureHook теперь ставятся только при наличии метода/объекта. Проверены все остальные hook-цели ElvUI-скинов по коду форка: `PositionAndSizeBar(Pet/ShapeShift)`, `LoadKeyBinder`, `Auras.CreateIcon/UpdateAura/UpdateTempEnchant`, `UF.Configure_Castbar/Configure_ClassBar/UpdateNameSettings/Configure_Threat/Configure_Power/PostUpdateAura/Configure_AuraBars/Construct_AuraBars`, `DB.CreateBar`, `DT.BuildPanelFrame`, `Layout.ToggleChatPanels`, `M.LootRoll_Create`, `NP.Construct_AuraIcon`, `E.ToggleOptions/Install/ToggleMoveMode/CreateStatusFrame`, `S.SkinLibDropDownMenu`, `TotemTracker.Initialize` — присутствуют.
- **GameBar не появлялся (меню сверху по центру)**: после фикса SecureHook Initialize доходит до конца, но бар так и не виден, и ошибок нет — единственный механизм показа бара — `RegisterStateDriver(self.bar, "visibility", ...)`, а дефолтная видимость `"[petbattle] hide; show"` содержит условие `[petbattle]`, которого на этом клиенте нет (пет-баттлов нет вообще: нет ни `C_PetBattles`, ни PetBattle-фреймов). `SecureCmdOptionParse` с невалидным условием не кидает Lua-ошибку, но и не вычисляется в `"show"` → `resolveDriver` (клиентский `SecureStateDriver.lua`) не вызывает ни `Show()`, ни `Hide()` → бар навсегда остаётся в дефолтном скрытом состоянии. Фикс: (1) дефолт в `Settings/Profile.lua` заменён на `"show"`; (2) `GB:UpdateBar` теперь вырезает `[petbattle]`-сегменты из любого значения видимости (включая пользовательские) и фолбэчит на `"show"`; (3) та же невалидная конструкция убрана из `RaidMarkers` (`"[group] show; hide"`), `MinimapButtons` и `SwitchButtons` (все — `"show"`).
- **Системный фикс: ошибки инициализации модулей теперь видны.** `W:InitializeModules` оборачивал `module.Initialize` в `xpcall(..., F.Developer.LogDebug)`, а `LogDebug` молчит при logLevel<4 — этот класс тихих падений уже дважды убивал модули целиком (Skins, GameBar). Обработчик ошибки заменён на `F.Developer.ThrowError` — любая ошибка Initialize теперь выводится в UI errors frame (формат `WindTools [ERROR] <module> failed to initialize: <err>`), как у остальных ошибок проекта.
- **НАЙДЕНА ГЛАВНАЯ СИСТЕМНАЯ ПРИЧИНА: бэкпорт потерял регистрацию `PLAYER_LOGIN`.** Коммит 030b8032 добавил `self:RegisterEvent("PLAYER_LOGIN")` в `W:Initialize`, но в рабочей копии она отсутствовала (осталась только `PLAYER_ENTERING_WORLD`). Без неё `W:InitializeModules` **вообще никогда не запускался** — модули, у которых есть только `Initialize` (например, **Skins — у него нет ProfileUpdate!**), не инициализировались вовсе (поэтому «фикс AceGUI» сам по себе тени не включал), а модули с `ProfileUpdate` (GameBar, Contacts) инициализировались только через `E:UpdateAll → W:UpdateModules → pcall(ProfileUpdate)` — с **молчаливым** pcall. Итог: модуль Contacts молча не появлялся, а ошибки инициализации не всплывали. Исправлено: (1) `RegisterEvent("PLAYER_LOGIN")` восстановлен в `W:Initialize`; (2) `W:UpdateModules` переведён с молчаливого `pcall` на `xpcall + F.Developer.ThrowError` (ошибки ProfileUpdate теперь видны).
- **Item/Contacts (не было фрейма контактов в отправке почты)**: модуль существует (`Modules/Item/Contacts.lua`), API-совместим с клиентом (проверено по APIDocumentation: `GetFriendInfo` возвращает таблицу `FriendInfo` c полями `connected/name/className`, `BNGetNumFriends` есть, `MenuUtil.CreateContextMenu` реализован в клиентском `Custom_Menu/MenuUtil.lua`), но инициализировался только через молчаливый pcall-путь — а при неинициализированном `E.global.WT.item.contacts` падал на `UpdateAltsTable` без следа. `UpdateAltsTable` теперь создаёт структуру `E.global.WT.item.contacts` при отсутствии (дефолты `alts/favorites/updateAlts`), `Initialize` guardит nil-`self.db`, `BuildFavoriteData` nil-safe. После восстановления `PLAYER_LOGIN` фрейм контактов появляется справа от MailFrame при открытии вкладки «Отправить».
- **Media/иконки (не отображались вообще)**: пути текстур WindTools строились со **смешанными разделителями** — `MediaPath` (`Interface\Addons\ElvUI_WindTools\Media\`, чистые обратные слэши) + `type .. "/" .. file` (прямые слэши) → `...\Media\Icons/Accept.tga`. Все рабочие аддоны клиента (ElvUI — 0 прямых слэшей в путях, FriendList — чистые `\`) используют один стиль; клиент не резолвит пути с двумя разделителями (текстуры молча пустые, без ошибок). **Важно: первый проход чинил только разделитель между `type` и `file`, но 52 из 77 вызовов `AddMedia` передают имена файлов с прямыми слэшами внутри (`"GameBar/Achievements.tga"`, `"Categories/Item.tga"`, `"Covenants/Kyrian.tga"`, `"Button/Lock.tga"`, `"Illustration/Murloc1.tga"` и т.д.) — пути всё равно получались смешанными (`...\Icons\GameBar/Achievements.tga`), поэтому иконки GameBar и категорий оставались пустыми. Окончательный фикс — нормализация в самой `AddMedia`: `file:gsub("/", "\\")` — покрывает ВСЕ 77 вызовов (симуляция: 0 смешанных путей). Вместе с ранее исправленными `AddRoleIconPack`, `F.GetClassIconWithStyle`, шрифтами (обе ветки локализации), statusbar'ами (WindTools + ToxiUI) и звуками все пути медиа теперь чистые. Потребители иконок (GameBar `W.Media.Icons.bar*`, Contacts, RaidMarkers и т.д.) берут пути из `W.Media` — один фикс покрывает их все. Формат TGA проверен (291 файл type=10 RLE + 27 type=2, 32-bit — оба поддерживаются 3.3.5a), все 318 файлов медиа синхронизированы с игровой папкой.
- **Item API (Inspect падал при открытии персонажа)**: `C_Item` на этом клиенте — **реальная, но неполная** таблица функций (по APIDocumentation есть GetItemInfo/GetItemGem/GetItemStats/GetItemQualityColor/GetItemCooldown/IsUsableItem), а retail-методы `GetCurrentItemLevel`, `GetDetailedItemLevelInfo`, `GetItemNumSockets`, `IsCorruptedItem`, `IsCosmeticItem`, `IsItemKeystoneByID` отсутствуют — и Wrath-глобалов для них тоже нет (проверено по APIDocumentation, FrameXML клиента и Questie-335; `GetItemNumSockets`/`GetDetailedItemLevelInfo` — Cata+, в 3.3.5 их нет). Незащищённые capture-привязки падали с `attempt to call upvalue 'C_Item_GetCurrentItemLevel' (a nil value)` при открытии персонажа. В CompatibilityLayer добавлены call-time accessor'ы: `GetCurrentItemLevel` (Wrath-фолбэк — nil, вызывающий код далее берёт `E:GetGearSlotInfo(unit, slot).iLvl`), `GetDetailedItemLevelInfo` (Wrath: itemLevel — 4-й возврат `GetItemInfo(link)`), `GetItemNumSockets` (Wrath: 0 — клиент не умеет считать сокеты по ссылке), `IsCorruptedItem`/`IsCosmeticItem`/`IsItemKeystoneByID` (false — коррупция/трансмог/ключи отсутствуют на Wrath). Переведены: Inspect (4 привязки + латентные краши :541/:615/:1070), AlreadyKnown (`IsCosmeticItem`), QuickKeystone (`IsItemKeystoneByID`), LibOpenRaid/GetPlayerInformation (nil-safe локальные фолбэки — библиотека standalone, без W). GuildNewsItemLevel и ChatLink уже ссылались на `W.Compatibility.GetDetailedItemLevelInfo` (раньше — nil, молча деградировали; теперь реальный iLvl).
- **Misc/MoveFrames (краш при перетаскивании фреймов, `self.db` nil)**: `MF:Remember` читал кэшированный `self.db` безусловно (`attempt to index field 'db' (a nil value)` при OnMouseUp), а хуки OnMouseDown/OnMouseUp ставятся не только из `MF:Initialize`, но и через `MF:InternalHandle` из других модулей (Contacts/Inspect/EventTracker/LFGList/скины) — `IsRunning()` при этом проверяет **живой** `E.private.WT.misc.moveFrames.enable`. Если Initialize не отработал (например, `E.private.WT` ещё не материализован на момент логина — ранний `return`, `self.db` остаётся nil), хуки всё равно вешаются, и первый же драг падает. Фикс: добавлен `MF:GetDB()` (nil-safe цепочка: `self.db` → живой `E.private.WT.misc.moveFrames`), на него переведены `IsRunning`/`Remember`/`Reposition`/`EnsureWindowInTheScreen`/`HandleElvUIBag` (заодно закрыты латентные `db.framePositions` nil-краши), а `Initialize` читает private DB с nil-guard'ом вместо прямого `E.private.WT.misc.moveFrames`.
- **Опции WindTools: невидимый текст на неактивных вкладках (`childGroups = "tab"`)**: окно настроек рендерит модули категории как горизонтальные вкладки AceGUI TabGroup (Options/Core.lua задаёт `childGroups = "tab"` всем категориям). Активная вкладка (текст через `SetDisabledFontObject(GameFontHighlightSmall)`) рендерится белым, а неактивные — через дефолтные `GameFontNormalSmall`/`GameFontDisableSmall` — **без текста вообще** (по скриншоту пользователя: активная вкладка «Панель дополнительных предметов» с белым текстом, у остальных текст пустой). Причина: этот клиент — retail-style (SharedXML/SharedFontStyles.xml: `GameFont*` объявлены как виртуальные шаблоны, `GameFontNormalSmall` наследует `SystemFont_Shadow_Small` с золотым цветом, `GameFontDisableSmall` отсутствует в SharedFontStyles), и дефолтные объекты шрифтов не применяются к FontString вкладки, тогда как `GameFontHighlightSmall` (используемый выбранной вкладкой) работает. Фикс в `Modules/Skins/Libraries/Ace3.lua`: обработчик AceGUI-виджета `TabGroup` (`S:Ace3_TabGroup`, регистрируется через `AddCallbackForAceGUIWidget` с checker-функцией `true` — это функциональный баг, а не эстетический скин) перехватывает `widget.CreateTab` и принудительно ставит **доказанно рабочий** `GameFontHighlightSmall` на Normal/Highlight/Disabled-состояния каждой вкладки + явный белый `SetTextColor(1, 1, 1)`.
- **Массовые ошибки инициализации после включения видимости Initialize-ошибок** (ранее молча подавлялись pcall'ом; теперь каждый факт стал виден, и все они оказались одним классом — retail-only API/фреймы, отсутствующие на 3.3.5a). Вычищено по одному классу:
  - **`Ambiguate`** (ChatText, флада 481 ошибка): retail-хелпер, в Wrath его нет (лежит только игровой shim `Compat335.lua` у MRT). Добавлен локальный фолбэк `function(name) return (name:match("^([^%-]+)") or name) end` (отрезает realm по `-`); дополнительно walkthrough-кэш и `GuildRoster`-пути теперь не падают на nil-имени.
  - **`Item` instance API** (`Core/Utilities/Async.lua`, ExtraItemBar): `Item:CreateFromEquipmentSlot`/`ContinueOnItemLoad`/`IsItemEmpty` — retail-only. `WithItemSlotID` теперь: (1) при наличии retail Item → прежний путь; (2) на Wrath → нил-безопасный стаб из `GetInventoryItemLink` с `GetItemName`/`GetItemID` (ExtraItemBar и так guardит отсутствие инстанса).
  - **`Scale:SetTarget`** (RaidMarkers): метод есть только у retail `SimpleAnim`; классическая `Scale`-анимация авто-таргетит родительский регион. Guard `if scaleAnim.SetTarget then` (вызванный `SetOrigin` остаётся — он есть).
  - **SecureHook на не-существующие retail-цели**: `EventTracker` (`QuestMapFrame`+`QuestSessionManager`), `ObjectiveTracker` (`ScenarioObjectiveTracker`), `SmartTab` (`ChatEdit_CustomTabPressed`), `FriendList` (`FriendsFrame_UpdateFriendButton`, зависимость от `FriendsFrameBattlenetFrame`/`RecentAlliesFrame`), `Skins/Blizzard` (`Alerts` — ~25 alert-систем retail, `Misc` — кинематографические глобалы, `UIWidget`, `WorldMap` quest-слой). Все обёрнуты в проверку существования цели/глобала.
  - **CreateFrame("DropdownButton")** (AchievementTracker): retail-тип фрейма (реализован retail SharedXML/DropdownButton.lua), на 3.3.5a не зарегистрирован → `Unknown frame type`. Модуль целиком retail (SetupMenu/RootMenuDescriptionProxy) — отключён на клиенте через pcall-детект `AT_RetailDropdownAvailable()`.
  - **`LFGList`** (Premade Groups + mythic+): система Legion+, полностью retail (`LFGListFrame`, `C_MythicPlus`, `Blizzard_ChallengesUI`, `LFGListSearchPanel_*` — всё nil на Wrath). В `LL:Initialize` early-return если `_G.LFGListFrame` отсутствует.
  - **Nil-фреймы в скинах Blizzard/ElvUI**: `DressingRoom` (`SetSelectionPanel`/`CustomSetDetailsPanel`), `Friends` (`FriendsFrameBattlenetFrame`+BN), `Loot` (`BonusRollFrame`), `Merchant` (`MerchantMoneyFrame.GoldButton`), `SettingsPanel` (retail `SettingsPanel`), `DebugTools` (`TableAttributeDisplay`/`TableInspectorMixin`), `Barbershop` (retail `CharCustomizeFrame`; Wrath-`BarberShopFrame` оставлен), `ElvUI/ActionBars` (`ExtraActionBarFrame`/`ExtraActionButton*`), `ElvUI/LootRoll` (`IsForbidden` на не-Region), `ElvUI/UnitFrames` (`MainGlow` отсутствует в threat-индикаторе форка — фикс помогает модулю NameClip), `Immersion` (`ReputationBar` отсутствует в Wrath-версии аддона). Везде добавлены guard'ы (nil-check фрейма/метода) — модули на Wrath молча пропускают retail-часть и продолжают бэкпортные части.
  - **`RectangleMinimap`** (`MinimapBackdrop.StaticOverlayTexture`), **`WorldMap` Reveal** (`EnumeratePinsByTemplate`/`MapExplorationPinTemplate`, `C_AddOns_IsAddOnLoaded`→`W.Compatibility.IsAddOnLoaded`), **`AchievementScreenshot`** (`AchievementAlertSystem:GetAlertContainer()` — retail AlertFrameSystem), **`Tooltips`-скин** (`tt:IsForbidden()` на списке тултипов, часть из которых не Region): все обёрнуты в guard'ы. Принцип одинаковый: **если retail-цель отсутствует на 3.3.5a — молча пропустить** (retail-фича, которой на клиенте нет), не эмулируя её несуществующим API.
  - **Второй проход (после первого `/reload` всплыли более глубокие retail-вызовы внутри модулей)**: (1) `button:ClearAttribute("marker")` в `RaidMarkers` — retail-метод, на 3.3.5a атрибуты снимаются `SetAttribute(key, nil)` → guard; (2) стаб `WithItemSlotID` дописан — `GetItemQualityColor` (из `GetItemInfo` rarity + глобальный `GetItemQualityColor`) для ExtraItemBar; (3) `LFGList` — гейт заменён на `C_MythPlus.RequestCurrentAffixes` (клиент Sirus шлёт retail-style `FrameXML/LFGList.lua`, т.е. `LFGListFrame` может существовать, но `C_MythicPlus` всё равно отсутствует — гейт по реально падающему API); (4) **AceHook `SecureHook`/`RawHook` на retail-методы, которых нет в объектах форка**: `ObjectiveTracker`/`ScenarioObjectiveTracker:UpdateCriteria`, `Absorb`/`UF:SetTexture_HealComm`, `TierSet`/`E.ScanTooltip:SetInventoryItem`, `Tooltips Core`/`ET.AddMythicInfo`+`SetUnitText`+`RemoveTrashLines`, `SmartTab`/`chat.editBox:SecureTabPressed`, `Friends`/`RecruitAFriendRewardsFrame:UpdateRewards`+`FriendsFrame_UpdateFriendButton` — каждый обёрнут в `type(<target>) == "function"` guard (AceHook требует существования метода, иначе «non existing target»); (5) `Loot`/`GroupLootHistoryFrame` (retail), `Tooltips`-скин/`GameTooltip_AddWidgetSet` (retail глобал), `Immersion`/`RewardsFrame.SkillPointFrame` (отсутствует в Wrath-билде аддона) — заguещены.
  - **Третий проход (после второго `/reload` — единичные глубокие nil-capture и AceHook-хуки)**: (1) `ExtraItemBar` — `C_TradeSkillUI.GetItemReagentQualityInfo` (retail-система качества реагентов, на 3.3.5a нет) → capture сделан нил-безопасным (`or function() return nil end`), так что скип показывает пустой qualityTier; заодно нил-безопасны `C_QuestLog_GetQuestIDForLogIndex`/`C_QuestLog_GetDistanceSqToQuest` (Wrath — распознают реагент/квест по-другому, корректная деградация через `or nil → distance 1e8`); (2) `Inspect` — те же retail-хелперы `C_TradeSkillUI_GetItem*QualityByItemInfo` сделаны нил-безопасными (декоративно, on Wrath `WithItemID`-callbacks и так не вызываются, т.к. нет `Item.CreateFromItemID`); (3) `TierSet` — на реальном клиенте падали `self:Hook(ET, "INSPECT_READY")` и `self:Hook(ET, "PopulateInspectGUIDCache")` (методы отсутствуют в ElvUI-форке) — оба заguещены по `type(ET.<method>) == "function"`; (4) `Tooltips`-скин — `QueueStatusFrame` на клиенте **существует** (retail-style FrameXML Sirus), но метода `Update` нет → guard по `type(...Update) == "function"`; (5) **весь класс `tt:IsForbidden()` на возможные не-Region `tt`** (приходит по `GameTooltip_SetDefaultAnchor`/OnTooltipCleared): `Tooltips/Core.lua` (`ClearInspectInfo`, `ElvUIRemoveTrashLines`), `Tooltips/HealthBar`, `Skins/Blizzard/Tooltips:49` (`StyleIconsInTooltip` вызывал IsForbidden раньше понимания NumLines), `Social/Emote` — все переведены на идиому `not tt or (tt.IsForbidden and tt:IsForbidden())` (и `(not holder.IsForbidden or not holder:IsForbidden())` для Emote; там же `C_ChatBubbles_GetAllChatBubbles` уже нил-безопасен → пустой список).
  - **Четвёртый проход (глубокие retail-вызовы в тултипах и по всему проекту родовой `Ambiguate`)**: (1) **`Tooltips/Core` `InspectInfo`** — `ET:GetDisplayedUnit(tt)` (retail ElvUI-метод; на Wrath — `tt:GetUnit()` с сохранением существующего `E:GetMouseFocus`-фолбэка) и runtime `ET:AddInspectInfo` — оба заguещены по `type(...) == "function"`; (2) **`Tooltips/UnitInfo`** — `UnitEffectiveLevel` (Cata+) и `UnitLevel` — оба выведены на никогда-nil-фолбэки (`or function() return 0 end`), чтобы upvalue не был nil на любом клиенте независимо от порядка загрузки; `ET:GetLevelLine` (retail; деградирует к обычному тексту — в остальном функция целиком nil-guarded через `levelLine`/`specLine`); (3) **родовой класс `Ambiguate`** (после ChatText всплыли ещё multiple мест): в `SmartTab`, `Core/KeystoneInfo`, `Libraries/LibKeystone` добавлены одноимённые локальные Wrath-шим-фолбэки, а в `Core/CompatibilityLayer` установлен **глобальный `_G.Ambiguate`**, покрывающий все неqualified-использования (LibOpenRaid.lua:435/472 и GetPlayerInformation.lua:1090 — те недостижимы без установленного аддона OpenRaid, но глобал делает их безопасными навсегда).
- **Игровые кнопки GameBar по коллекциям — раскладка табов кастомного журнала отличается**: этот клиент (Sirus) использует не стандартный журнал коллекций, а `Custom_Collections` с **5 табами** (`CollectionsJournal_UpdateSelectedTab`: 1=MountJournal, 2=PetJournal, **3=WardrobeCollectionFrame (модели/облики)**, **4=ToyBox**, 5=HeirloomsJournal). Кнопка «Игрушки» (barToyBox) в GameBar кликала `CollectionsJournalTab3` → открывалась **Wardrobe (модели)**, а не игрушки. Исправлено: TOY_BOX → `CollectionsJournalTab4`. Mounts (Tab1) и Pets (Tab2) были верные.
- **`[petbattle]` в visibility**: пет-баттлов в 3.3.5a нет, `[petbattle]` — невалидное условие (ошибка «Неизвестный параметр макроса»). Дефолты `bar1`–`bar5` в `Settings/Profile.lua` имели `visibility = "[petbattle]hide;show"` — заменены на `"show"`. Рантайм уже режет `[petbattle]`-сегменты (GameBar.lua `UpdateBar`), поэтому и сохранённые значения оставшихся пользователей покрыты.
- **Кнопка «Список друзей» (GameBar FRIENDS) не открывала список**: макрос был `/cleartarget\n/friends`. Обработчик `/friends` на этом клиенте (ChatFrame.lua `SlashCmdList["FRIENDS"]`) при пустом сообщении и сброшенном target (после `/cleartarget`) уходит в ветку `ToggleFriendsPanel()` (не тот панель) — список друзей не открывается. Надёжный способ — глобал `ToggleFriendsFrame` (определён в FriendsFrame.lua; именно им пользуется Datatexts/MicroMenu). Макрос заменён на `/run ToggleFriendsFrame(1)` (открывает FriendsFrame на табе «Друзья»).
- **Правые клики GameBar на retail-API без аналога на 3.3.5a**: `C_MountJournal.SummonByID` (нет в C_Utils клиента), `C_PetJournal.SummonRandomPet`/`HasFavoritePets` (есть только `SummonPetByPetID`) и `WeeklyRewards_ShowUI` (Dragonflight, вообще отсутствует) — в `/run`-макросах кнопок «Коллекции/Еженедельники/Журнал встреч» вызывали Lua-ошибку. Обёрнуты в `if <API> then ... end`, чтобы при отсутствии беззвучно ничего не делать.
- **Кнопка «Рюкзак» (GameBar BAGS) — звук играет, окно не видно**: кнопка кликала `_G.ToggleAllBags()` — это **глобал ElvUI** (Bags.lua `_G.ToggleAllBags = ToggleAllBags`), который маршрутизирует в Blizzard `OpenAllBags` (в ElvUI-ветке раскрытия/скрытия на 3.3.5a сумки открываются, но фрейм не становится видимым). Надёжный открыватель — стандартный `_G.ToggleBackpack()` (это кнопка B/стандартный рюкзак), и его ElvUI хукает корректно в обоих состояниях (`B:SecureHook('ToggleBackpack')`). Заменено на `local toggle = _G.ToggleBackpack or _G.ToggleAllBags; toggle()` (фолбэк на всякий случай).
- **`CooldownFrame_Set` (retail-глобал, флада 300k в ExtraItemBar)**: на 3.3.5a такого глобала нет — классическое имя **`CooldownFrame_SetTimer`** (определён в Cooldown.lua, им пользуются ActionButton/BankFrame/ContainerFrame и т.д.). В `ExtraItemBar.lua` capture `local CooldownFrame_Set = CooldownFrame_Set` был nil → OnUpdate каждый тик падал с `attempt to call global 'CooldownFrame_Set'`. Capture переведён на `local CooldownFrame_Set = CooldownFrame_SetTimer or CooldownFrame_Set` (оба вызова на строках остаются под локалью — резолвятся в рабочий `CooldownFrame_SetTimer`).
- **Глобальный `_G.Ambiguate` (шейм в CompatibilityLayer) — баг тенирования**: в функции `function _G.Ambiguate(name, type)` второй параметр назывался `type`, тенируя встроенную функцию → `type(name)` в теле падал с `attempt to call local 'type' (a string value)`. Параметр переименован в `mode`. Остальные шеймы (ChatText/SmartTab/KeystoneInfo/LibKeystone) — с одним параметром `name`, не тенируют `type` — не тронуты.
- **Контакты в отправке почты (`Modules/Item/Contacts`)**: (1) вкладка **«Друзья онлайн»** пустовала — retail-фолбэк `GetNumFriendsOnline` на Wrath отсутствует (nil → вызов падал). На этом клиенте друзья считаются через глобалы `GetNumFriends()` (возвращает `numTotal, numOnline`) и `GetFriendInfo(i)` (возвраты `name, level, class, area, connected, status, note`). `BuildFriendsData` теперь ветвится по наличию метода `C_FriendList.GetNumOnlineFriends` (на этом клиенте `C_FriendList` **есть**, но это заглушка только с `IsInvisible`/`CanChangeInvisibility`/`ToggleInvisible` — без `GetNumOnlineFriends`/`GetFriendInfoByIndex`; поэтому ветвление по `not C_FriendList` ошибочно вело в мёртвую retail-ветку и падало `attempt to call upvalue 'C_FriendList_GetNumOnlineFriends'`). Когда метода нет — Wrath-цикл по `GetNumFriends`/`GetFriendInfo`, фильтр `connected`; иначе — прежний retail-код. Капч `C_FriendList_GetNumOnlineFriends` имеет Wrath-фолбэк `select(2, GetNumFriends())`. (2) **«Альтернативный персонаж»** наполнялся только текущим персонажем (авто-сбора альтов на Wrath нет — в игре нет API списка своих персонажей). Добавлен пункт контекстного меню **«Add This Alt»** (`L["Add This Alt"]` в enUS/ruRU) для любого контакта с классом, который пишет контакт в `E.global.WT.item.contacts.alts[realm][faction][name]` — после этого он появляется во вкладке альтов.
- **ObjectiveTracker — чёрная подложка и «бесконечный скролл» (кастомный трекер Sirus)**: на 3.3.5a-форке клиент использует собственный трекер (`Interface/FrameXML/Custom_ObjectiveTracker/*`), где высоты блоков/строк считает сам движок (`block:SetHeight`, `contentsHeight`, `ScrollChild:SetSize`). Причины: (1) `CosmeticBar` рисовал непрозрачную подложку `backdrop:SetTemplate()` под заголовками — чёрные полосы; заменено на `SetTemplate("Transparent")` (остались рамка/тень). (2) Насильные `text:Height(GetStringHeight()+2)` в `HandleBlockHeader` и `line:Height(GetHeight())` в `HandleLine` ломали кастомную раскладку и раздували содержимое трекера → «бесконечный скролл»; оба переназначения убраны (шрифты/цвета/noDash сохранены). (3) `CosmeticBar` теперь санитизирует размеры (NaN / `<=0` / `>10000` → дефолт 250×2) и защищён от отсутствующего `header.Text` в DYNAMIC-режиме.

## Карта реального API клиента (по APIDocumentation и Questie-335)

Проверено по установленному в игре аддону `APIDocumentation` (интроспектор реального API этого клиента) и по `Questie-335` (рабочий аддон на этом клиенте, имеет собственный compat-слой):

**Присутствует на клиенте (Sirus):**
- `C_Timer` — `After`/`NewTicker`/`NewTimer` (ElvUI-Sirus зовёт `C_Timer:NewTicker` напрямую).
- `C_QuestLog` — `GetQuestInfo`, `GetQuestObjectives`, `IsOnQuest`, `IsQuestFlaggedCompleted`, `ShouldShowQuestRewards`, `GetMaxNumQuests`, `GetMaxNumQuestsCanAccept`.
- `C_GossipInfo` — `GetActiveQuests`, `GetAvailableQuests`, `GetNumActiveQuests`, `GetNumAvailableQuests`, `GetOptions`, `SelectActiveQuest`, `SelectAvailableQuest`, `SelectOption` и др.
- `C_AddOns` (только `GetAddOnMetadata` как метод), `C_SpellBook` (`GetSpellLinkFromSpellID`), `C_Club`, `C_PartyInfo`, `C_TooltipInfo` (`Show/HideHyperlinkTooltip`), `C_SpecializationInfo` (namespace есть, **функций нет** — спеки реализуются ElvUI-Sirus на `E.GetSpecialization`/`E.GetSpecializationInfo`/`E.GetInspectSpecialization`/`E.GetSpecializationInfoByID`).
- Wrath-глобалы: `GetCVar`/`SetCVar`, `GetItemInfo`/`GetItemInfoInstant`/`GetItemCount`/`GetItemCooldown`/`GetItemQualityColor`/`GetDetailedItemLevelInfo`, `GetContainerItemID`/`UseContainerItem` и др., `GetSpellInfo`/`GetSpellTexture`, `IsAddOnLoaded`, `GetQuestLogTitle`/`GetNumQuestLogEntries`/`GetQuestLogLeaderBoard`/`GetNumQuestLeaderBoards`, gossip-глобалы.

**Отсутствует на клиенте (ни документации, ни рабочей реализации):**
- `GetQuestTagInfo` (Questie реализует сам из таблицы данных `QuestTag[questId]`);
- `IsQuestFlaggedCompleted`/`IsQuestFlaggedCompletedOnAccount` как вызываемые (Questie сам трекает завершения из событий) — чекер деградирует в `false`;
- `GetProfessions`, `GetProfessionInfo`, `GetServerTime`;
- ~~`C_CVar`, `C_Item`, `C_Container`, `C_Map`, `C_Spell`, `C_BattleNet`, `C_ChallengeMode`, `C_MythicPlus`, `C_ScenarioInfo` (целиком namespace'ы).~~ **Неверно** — см. раздел «Sirus compat audit» ниже: `C_Item`/`C_Map`/`C_ChallengeMode`/`C_MythicPlus` на Sirus есть, но частичные; `C_CVar`/`C_AddOns` — PrivateNamespace (не глобальны). Проверять нужно конкретные методы, а не namespace.

`Core/CompatibilityLayer.lua` переписан на **call-time резолвинг**: каждый accessor обращается к `_G` в момент вызова (поздняя регистрация API клиентом больше не проблема), имена методов приведены к документированным (`GetQuestInfo` вместо `GetInfo` и т.п.), фейковые `function() return nil end`-фолбэки убраны — отсутствие API возвращается как `nil` и обрабатывается в точке вызова.

## Статическая проверка

- `git diff --check`: проходит.
- Статический поиск необёрнутых optional `C_*` initializer-выражений вне намеренно отключённых библиотек: 0.
- Статический поиск повреждённых склеенных Lua-деклараций: 0.

- Полный Lua compile check: невозможно выполнить, поскольку в окружении отсутствуют `lua5.1`, `luac5.1` и `luac`.
- Runtime smoke-test: требует запуска модифицированного клиента.

## Статус блоков

| Блок | Статус | Примечание |
|---|---|---|
| Core / Settings / Options | ADAPT | Добавлен общий compatibility layer и legacy fallback |
| Item | ADAPT | Базовые item/container сценарии защищены; Inspect/collection требуют runtime проверки |
| Tooltips | ADAPT | Legacy-safe guards; structured tooltip отключается при отсутствии processor; `xpcall`-замыкание в `T:Event` переписано на capture+unpack (Lua 5.1: `...` вне vararg-функции — compile error). |
| Maps | ADAPT | Map/waypoint функции безопасны; WorldMap требует клиентского runtime |
| Quest | ADAPT/REWRITE | Старые quest API используются через fallback; retail Prey/structured progress gated |
| Social | ADAPT | Friends/BNet/Club функции нейтральны при отсутствии namespace |
| Misc | ADAPT | CVar, timer, summon и optional integrations защищены |
| Combat | ADAPT | Keystone/damage meter optional; secure UI требует runtime проверки |
| UnitFrames | ADAPT/REPLACE | Используются ElvUI tags и legacy unit API, где возможно |
| Skins | ADAPT/REPLACE | Blizzard/retail skins guarded; не меняют ElvUI |
| Libraries | ADAPT | LibKeystone/ObjectiveProgress защищены; LibOpenRaid/RangeCheck остаются крупным риском |

## Критичные оставшиеся ограничения

1. `LibOpenRaid` содержит крупные retail-only ветки (`C_Traits`, `C_ClassTalents`, `C_UnitAuras`, modern timers) и требует отдельного Wrath-профиля или отключения.
2. `LibRangeCheck-3.0` содержит legacy-safe проверки modern spell/item/map API; на stock 3.3.5 range checkers без подтверждённых spell/item методов могут быть недоступны, но загрузку не ломают.
3. `Social/ChatText`, `Social/ContextMenu` и `Social/ChatLink` используют современные структуры данных; fallback предотвращает загрузочное падение, но не гарантирует полную функциональность.
4. `Quest/TurnIn`, `AchievementTracker`, `Maps/WorldMap` и `Misc/GameBar` требуют проверки реальных сигнатур изменённого клиента.
5. Compatibility fallback предназначен только для безопасной загрузки. Он не эмулирует игровую логику и не должен считаться реализацией retail API.
6. Secure frames, combat lockdown, templates и custom client behavior невозможно подтвердить статически.

## Следующий обязательный этап

- Запустить чистый клиент с ElvUI + WindTools.
- Собрать `/dump` capability report для всех namespace и методов.
- Проверить ошибки Lua при login, `/reload`, входе/выходе из мира и combat lockdown.
- Сначала стабилизировать Core, Item, Tooltips, Chat и UnitFrames.
- Затем отдельно переписать или отключить LibOpenRaid/LibRangeCheck.
- После runtime report заменить placeholder fallback на точные client adapters там, где custom client API подтверждён.

---

# Полный аудит (2026-08-28, повторный проход по заданию)

## 1. Структура проекта

- **Toc**: `ElvUI_WindTools.toc` (Interface 30300), RequiredDeps: ElvUI.
- **Загрузка**: Preflight → Libraries → Initialize → Locales → Media → Core → Settings → Modules → Options.
- **Ядро**: `Core/` (Compatibility, CompatibilityLayer, Core, Commands, Install, KeystoneInfo, Metadata, Options, UIError, Update, Functions/, Utilities/).
- **Модули** (11 групп): Announcement, Combat, Datatexts, Item, Maps, Misc, Quest, Skins, Social, Tooltips, UnitFrames.
- **Settings**: Global (E.global.WT), Profile (E.private.WT), Private (E.db.WT).

## 2. Ключевые находки по клиенту (patch-ruRU-i/DF/Interface)

| Что | Где | Вывод |
|---|---|---|
| `C_Timer:NewTicker/NewTimer/After` — **colon-методы** | SharedXML/C_TimerAugment.lua | Любой вызов без `self` ломается (`compare number with function`). Исправлены прямые вызовы в LibOpenRaid, LibKeystone, LibRangeCheck, EventTracker. |
| `FrameUtil`, `Mixin.lua`, `CallbackRegistry.lua` | SharedXML | Есть, но `FrameUtil_RegisterForTopLevelParentChanged` отсутствует — UIError переведён на AceHook. |
| `C_QuestLog` | FrameXML/Utils/C_QuestLog.lua | Только глобальные helper'ы, полноценного namespace нет — используется legacy QuestLog API. |
| `C_*` namespace (C_Map, C_Item, C_Spell…) | присутствуют частично | Capability-проверки перед каждым использованием; legacy-глобалы имеют приоритет. |
| Legacy map API | `GetCurrentMapAreaID`, `GetMapInfo`, `SetMapToCurrentZone`, `GetPlayerMapPosition`, `IsItemInRange` | Есть — используются в SuperTracker/WorldMap/PreyHunt/LibRangeCheck. |
| Frame-шаблоны | `BackdropTemplate`, `DropdownButton` **отсутствуют** | Все `CreateFrame(..., "BackdropTemplate")` убраны; dropdown через `UIDropDownMenuTemplate`/ElvUI. |

## 3. Аналоги в нашей ElvUI (d:/!sirus_addons/DF/ElvUI, 9.05)

| Нужное | Аналог | Статус |
|---|---|---|
| Установщик | `E:GetModule("PluginInstaller"):Queue(addon)` | **Реализован** — новый `Core/Install.lua` (3 страницы, пресеты через DB). |
| Дефолты DB | `E:CopyDefaults`, `E.db` из `E.DF.profile` + ElvDB | WindTools заполняет `E.db.WT`/`E.private.WT`/`E.global.WT` при загрузке. |
| Скины кнопок | `E:GetModule("Skins"):HandleButton/HandleCloseButton` | Используется PluginInstaller. |
| Таймеры | `E:Delay`, `E:ScheduleTimer` | Используются вместо `C_Timer` в горячих местах. |
| Медиа/шрифты | `E.media`, `F.GetCompatibleFont` | Используются. |
| Обновление | `E:UpdateAll` → WindTools `UpdateModules` | Используется пресетами установщика. |

## 4. Статус модулей (PORT/ADAPT/REWRITE/REPLACE/REMOVE)

| Модуль | Статус | Комментарий |
|---|---|---|
| Announcement (Core, Events, Goodbye, Keystone, Quest, ResetInstance, Utility) | ADAPT | Legacy quest/gossip/instance API; ResetInstance gsub-фикс. |
| CombatAlert | ADAPT | Legacy spell/aura. |
| ~~DamageMeterLayout~~ | REMOVED | Retail-модуль (Blizzard Damage Meter) выпилен полностью: файл, XML, Options, Settings. |
| DestroyTotem | ADAPT | Private DB + legacy totem API. |
| QuickKeystone | REMOVE (gated) | Keystone — retail-концепция; реальный API вызывается только при наличии. |
| RaidMarkers | ADAPT | World markers отсутствуют — raid icons. |
| Datatexts/MicroMenu | REWRITE | `DropdownButton` нет → legacy dropdown. |
| Datatexts/Range | ADAPT | LibRangeCheck legacy-путь. |
| Item/AlreadyKnown | ADAPT | Mount/pet/toy/heirloom через реальные C_* и legacy tooltip-скан; синтаксис исправлен. |
| Item/Contacts, DeleteItem, FastLoot, Trade | ADAPT | Legacy item/merchant API. |
| Item/ExtendMerchantPages | ADAPT | `GetMerchantItemInfo`. |
| Item/ExtraItemBar | REWRITE | Retail-структуры; legacy item/range path. |
| Item/Inspect | ADAPT | `GetItemInfo`, `GetItemStats`, спеки legacy; `GarrisonFollowerPortraitTemplate` (retail) заменён на нативный Wrath-портрет (Portrait + Level + SetLevel). |
| Social/ChatText | ADAPT | nil-arg1 guard: некоторые Wrath/Sirus чат-события приходят без payload — пропускаются (раньше падало в `E:RemoveExtraSpaces`). |
| Item/ItemLevel | ADAPT | `GetContainerItemLink` вместо `C_Item.DoesItemExist`. |
| Maps/EventTracker(+Data) | ADAPT | Timer-фикс, `IsQuestFlaggedCompleted`, legacy map info. |
| Maps/InstanceDifficulty | ADAPT | Legacy difficulty. |
| Maps/MinimapButtons | ADAPT | Legacy-фреймы без BackdropTemplate. |
| Maps/RectangleMinimap | ADAPT | Legacy minimap API. |
| Maps/SuperTracker | REWRITE | Waypoints retail-only; legacy map coords path; **рекурсия GetMapInfoCompat исправлена**. |
| Maps/WorldMap | ADAPT | Legacy `GetMapInfo`, без синтетических mapID. |
| Misc (Automation, AntiOverride, AddCNFilter, AutoToggleChatBubble, ExtraBindingButtons, GameBar, GuildNewsItemLevel, KeybindAlias, KeybindTextAbove, LFGList, LootPanel, Math, MoveFrames, Mute, PauseToSlash, ReshiiWrapsUpgrade, SpellActivationAlert, ExitPhaseDiving, HideCrafter, DisableTalkingHead) | ADAPT/REMOVE | Retail-only (SkipCutScene, ExitPhaseDiving, SpellActivationAlert, HideCrafter, ReshiiWrapsUpgrade) gated; остальные — legacy. |
| Quest/AchievementScreenshot, AchievementTracker, AutoCollapse, ObjectiveTracker, SwitchButtons | ADAPT | Legacy quest log/tracker. |
| Quest/PreyHunt | REMOVE (gated) | Retail world quests; legacy map-координаты сохранены. |
| Quest/Progress | REWRITE | `GetQuestLogTitle`/`GetQuestLogLeaderBoard` конвертеры. |
| Quest/TurnIn | ADAPT | Legacy quest/gossip API. |
| Skins/Core, ElvUI/*, Widgets/*, Libraries/* | ADAPT/PORT | Без BackdropTemplate; Tab-фикс; Ace3 skin через xpcall. |
| Skins/Blizzard/* | REPLACE/REMOVE | Retail-only фреймы (Delves, Housing, PerksProgram…) не существуют; Wrath-фреймы ADAPT. |
| Skins/Blizzard/{Quest,Gossip,Merchant,AuctionHouse,Character} | **REWRITE (done)** | Заменены retail-фреймы на реальные 3.3.5a: `QuestLogDetailFrame`/`QuestInfoItem1..10`/`GetQuestLogSelection` (вместо QuestLogPopupDetailFrame/RewardButtons/C_QuestLog), `EquipmentFlyoutFrame`/`CharacterModelFrame`/глобальный `ReputationDetailFrame` (вместо EquipmentFlyoutFrameButtons/CharacterModelScene/ReputationFrame.ReputationDetailFrame), убран WoW Token (MerchantToken/CurrencyTransfer/WoWTokenResults), аукцион переключён с `AddCallbackForAddon("Blizzard_AuctionHouseUI")` (аддон отсутствует — фрейм из FrameXML `Custom_AuctionHouseUI`) на немедленный `AddCallback`. |
| Skins/Addons/* | REPLACE | Скинятся только реально установленные аддоны (guarded). |
| Skins/Addons/Details | NEW | Скин Details (WotLK): тень/бэкдроп окна, чистая шапка вместо ball-арта, статусбар-текстура и шрифты строк; хуки CriarInstancia/CriaNovaBarra. |
| Social/ChatBar, ChatText, ChatLink | REWRITE | `ChatFrameUtil` отсутствует → legacy chat API. |
| Social/ContextMenu, Emote, FriendList, SmartTab | ADAPT | Legacy; FriendList без TimerunningUtil. |
| Tooltips/Core, GroupInfo, HealthBar, TierSet, UnitInfo | ADAPT | Legacy tooltip data. |
| Tooltips/Icons | ADAPT | `GetCurrencyInfo`, `GetEquipmentSetInfo` legacy. |
| Tooltips/Keystone, MythicPlus | REMOVE (gated) | Retail-only. |
| Tooltips/ObjectiveProgress, Progression | ADAPT/REWRITE | Legacy quest/achievement. |
| UnitFrames (Absorb, NameClip, QuickFocus, RoleIcon, Tags) | PORT | Legacy unit API + ElvUI tags. |
| Core/Install | **NEW** | Нативный установщик через PluginInstaller. |

## 5. Библиотеки

| Библиотека | Вердикт |
|---|---|
| LibDeflate | Оставить (профили/экспорт). |
| LibItemEnchant | Оставить (эффекты чар). |
| LibKeystone | Оставить, Wrath-совместимый (colon-timer фикс). |
| LibObjectiveProgressWT | Оставить (legacy quest progress). |
| LibRangeCheck-3.0 | Оставить (реальный `IsItemInRange`). |
| LibOpenRaid | Оставить, но на legacy-клиенте не регистрировать в `E.Libs` (уже gated); retail-ветки файлов колонизированы colon-timer фиксами. |

## 6. Архитектурные изменения

1. `Preflight.lua` — capability report до загрузки библиотек.
2. `Core/CompatibilityLayer.lua` — приоритет legacy-глобалов над неполными `C_*` namespace.
3. `W.ModuleRequirements` — retail-only модули не регистрируются без capability.
4. `Core/Install.lua` — нативный установщик (PluginInstaller) с пресетами, пишущими реальные DB-флаги.
5. Timer-вызовы приведены к colon-стилю клиента (`C_Timer.NewTicker(C_Timer, ...)`).
6. `BackdropTemplate`/`DropdownButton` полностью исключены.
7. Capability-флаги вычисляются заново при каждом входе (не кэшируются через `or`).

## 7. Performance-аудит

- Повторяющиеся E:Delay-поллеры: только установщик (5 c, останавливается после queue/complete) — приемлемо.
- Горячие пути (OnUpdate, tooltip scan) без изменений retail-логики; legacy `GetItemInfo`/tooltip-скан в AlreadyKnown вызываются только при наведении.
- `collectgarbage` по PLAYER_ENTERING_WORLD — как в оригинале.
- Нет новых бесконечных таймеров; тикеры EventTracker заменены разовым refresh.

## 8. Оставшиеся ограничения

1. `ChatFrameUtil` отсутствует — ChatBar/ChatText/ChatLink требуют полной переработки (текущий статус: не падают при загрузке).
2. Retail-only системы (Mythic+, world quests, waypoints, modern collections) в 3.3.5a отсутствуют — модули gated, не эмулируются.
3. Скины retail-фреймов (Delves/Housing и т.п.) физически не могут работать — оставлены guarded. Пять ключевых скинов (Quest/Gossip/Merchant/AuctionHouse/Character) переписаны на реальные фреймы 3.3.5a (см. раздел 4).
4. Полный Lua-compile/runtime тест требует клиента.

## 9. План тестирования

1. Чистый вход: ElvUI install → WindTools PluginInstaller (3 страницы, пресеты, Skip/Finish).
2. `/reload`, logout/login — установщик не показывается повторно после завершения.
3. Каждая группа модулей включается/выключается пресетами; `E:UpdateAll` без ошибок.
4. Открыть каждую страницу опций WindTools (`/ec → WindTools`) — без Lua-ошибок.
5. Проверить chat (ввод/ссылки), tooltip (итем/юнит), quest log, world map, minimap, merchant/bags.
6. Combat lockdown: вход/выход из боя без taint-ошибок.
7. Отключить WindTools — ElvUI работает как раньше.

---

# Sirus compat audit (ветка `sirus-compat`)

Источники: исходники клиента Sirus (`Interface/FrameXML`, `SharedXML`), ElvUI-for-Sirus 9.09.02 (у пользователя локально 9.05 + ElvUI_OptionsUI — расхождение версий), mock-харнесс загрузки (TOC-порядок, события, обход 3071 узла AceConfig).

## Карта API (проверено по исходникам Sirus)

| API | Sirus | Решение |
|---|---|---|
| `C_Timer` | `C_TimerAugment.lua`: `C_Timer:After`/`C_Timer:NewTicker` (через `:`), `C_Timer.NewTimer` (через `.`), поверх нативного `C_Timer2` | обёртки в CompatibilityLayer с правильной конвенцией вызова |
| Кастомные события | `FireCustomClientEvent` доходит только до фреймов с `RegisterCustomEvent` (`CHALLENGE_MODE_*`, `MYTHIC_PLUS_*`, `GET_ITEM_INFO_RECEIVED`) | авто-`RegisterCustomEvent` в AceEvent-обёртке; LibRangeCheck/LibKeystone явно |
| `GROUP_ROSTER_UPDATE` | нет (3.3.5) | алиас → `PARTY_MEMBERS_CHANGED` + `RAID_ROSTER_UPDATE` |
| Mythic+ | `C_MythicPlus.GetOwnedKeystoneLevel/ChallengeMapID` (может быть nil), `C_ChallengeMode.GetOverallDungeonScore`, `GetMapUIInfo`; нет `RequestCurrentAffixes`, `C_PlayerInfo.GetPlayerMythicPlusRatingSummary` | LibKeystone/KeystoneInfo адаптированы; тултип-рейтинг и premade-M+ отключены |
| CombatLog | Wrath-формат `COMBAT_LOG_EVENT_UNFILTERED` (аргументы события, без `CombatLogGetCurrentEventInfo`) | используется существующий 3.3.5-путь |
| Menu | `Menu`/`MenuUtil` есть, но UnitPopup — legacy UIDropDownMenu | ContextMenu грузится, но инертен; Contacts работает |
| ScrollBox/DataProvider, EventRegistry | есть | без изменений |
| `MuteSoundFile`, `C_ContentTracking`, `C_CooldownViewer`, `C_MountJournal.GetMountIDs`, `UnitNameUnmodified`, `securecallfunction` | нет | гейт по возможностям / фолбэки |
| `C_AddOns`, `C_CVar` | PrivateNamespace | глобальные Wrath-функции |
| `WOW_PROJECT_ID` | nil | не используется для детекта |

События retail без аналога (регистрируются молча, не срабатывают): `ITEM_CHANGED`, `INSPECT_READY`, `LOOT_READY`, `QUEST_WATCH_LIST_CHANGED`, `SCENARIO_*`, `PLAYER_AVG_ITEM_LEVEL_UPDATE`, `ENCOUNTER_*`, `COVENANT_CHOSEN`, `NEW_TOY_ADDED`, `TRAIT_*`, `UNIT_SPEC`, `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `USER_WAYPOINT_UPDATED`, `VIGNETTE_MINIMAP_UPDATED`, `CHAT_MSG_ADDON_LOGGED`, `PLAYER_PVP_TALENT_UPDATE`.

## Статус модулей (после sirus-compat)

| Модуль | Статус | Примечание |
|---|---|---|
| Core / Options | работает (харнесс) | обход всех опций без ошибок; недоступные функции выключены с пояснением |
| GameBar | исправлен | VirtualDT поддерживает `SetText` (Time/Friends/System ElvUI-Sirus) |
| KeystoneInfo / LibKeystone | адаптирован | Sirus M+ API, кастомные события |
| LibRangeCheck | адаптирован | `GET_ITEM_INFO_RECEIVED` через custom event |
| Math | частично | kanji-аббревиатуры скрыты (нет `E.Abbreviate` в ElvUI-Sirus) |
| Profiles (импорт) | исправлен | парсинг без retail-хелперов |
| LFGList | отключён | нет premade M+ API |
| MythicPlus (тултип) | отключён | нет rating summary |
| Progression, ObjectiveProgress, AchievementTracker, PreyHunt, SuperTracker, SpellActivationAlert, CooldownViewer skin | отключены | нет требуемого API; опции показывают причину |
| ContextMenu | инертен | UnitPopup на legacy-меню |
| Contacts | работает | |
| Skins | требует проверки в клиенте | харнесс не моделирует реальные фреймы |

## Ограничения
- Проверка выполнена на mock-харнессе и по исходникам; обязательна проверка в клиенте: вход, `/reload`, опции, бой, смена зоны.
- Обёртки событий ставятся на AceEvent текущей версии; апгрейд AceEvent другой копией после загрузки может их снять.
