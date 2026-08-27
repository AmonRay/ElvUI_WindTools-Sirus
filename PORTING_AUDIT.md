# WindTools — WoW 3.3.5a backport audit

Дата аудита: 2026-08-27

## Выполнено в текущем срезе

- Добавлен `Preflight.lua`, загружаемый до библиотек и `Initialize.lua`; он только собирает capability report и не мутирует глобальные Blizzard namespace.
- Добавлен централизованный `Core/CompatibilityLayer.lua`.
- Реализованы legacy fallback для addon, item, container, spell, CVar, chat, invite, reload и quest API.
- Добавлены capability flags, отличающие реальные namespace клиента от placeholder-таблиц.
- Retail-only модули `PreyHunt`, `SuperTracker`, `DamageMeterLayout`, `MythicPlus`, `ObjectiveProgress`, `Icons`, `Progression` не регистрируются без требуемых возможностей.
- Защищены загрузочные инициализаторы в Item, Tooltips, Maps, Quest, Social, Misc, Combat, Skins, UnitFrames и Options.
- `LibObjectiveProgress` и `LibKeystone` получили безопасные fallback для отсутствующих Wrath API.
- `LibKeystone` допускает retail/Wrath-compatible project IDs.
- `EventTracker` не требует `C_Timer.NewTicker`: при отсутствии timer API выполняется безопасный single refresh.
- ElvUI не изменялся.
- Финальный статический проход устранил прямые обращения к отсутствующим namespace в загрузочных локальных привязках; optional callbacks теперь регистрируются только при наличии processor/enum.
- Добавлены capability flags для cinematic и spell activation overlay; соответствующие модули не стартуют на клиенте без подтверждённых объектов.

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
| Tooltips | ADAPT | Legacy-safe guards; structured tooltip отключается при отсутствии processor |
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
