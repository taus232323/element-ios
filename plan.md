Ниже предлагаю рабочий план, чтобы идти по нему итерациями и не расползтись по всему репозиторию сразу.

Сейчас по iOS-коду уже есть базовый auth-flow: [`AuthenticationFlowCoordinator.swift`](/Users/taus/Projects/arcana-ios/ElementX/Sources/FlowCoordinators/AuthenticationFlowCoordinator.swift), [`AuthenticationStartScreenViewModel.swift`](/Users/taus/Projects/arcana-ios/ElementX/Sources/Screens/Authentication/StartScreen/AuthenticationStartScreenViewModel.swift), [`LoginScreenViewModel.swift`](/Users/taus/Projects/arcana-ios/ElementX/Sources/Screens/Authentication/LoginScreen/LoginScreenViewModel.swift), [`AuthenticationService.swift`](/Users/taus/Projects/arcana-ios/ElementX/Sources/Services/Authentication/AuthenticationService.swift). По нему видно, что сейчас вход завязан на старую схему с `username`/Matrix ID и поддержкой QR/OIDC/password, так что переделка будет именно точечной, но в нескольких слоях сразу.

**План работ**

1. **Зафиксировать целевой UX и расхождение с Android**
   - Сравнить iOS и Android по экранам входа, onboarding, ошибкам, кнопкам и брендингу.
   - Составить список, что переносим 1:1, а что упрощаем.
   - Отдельно отметить, где сейчас в iOS есть старые сценарии, которые нужно убрать: token-based вход, Matrix ID как основной логин, лишние ветки auth-flow.

2. **Переделать auth-слой под вход по почте**
   - Обновить [`AuthenticationServiceProtocol.swift`](/Users/taus/Projects/arcana-ios/ElementX/Sources/Services/Authentication/AuthenticationServiceProtocol.swift) и [`AuthenticationService.swift`](/Users/taus/Projects/arcana-ios/ElementX/Sources/Services/Authentication/AuthenticationService.swift).
   - Заменить логику, где `LoginScreenViewModel` парсит `username` и пытается извлекать homeserver из Matrix ID.
   - Привести `LoginScreen` к email-first логике: поле email, нормальные подсказки, валидация, ошибки.
   - Убрать/заглушить все остатки входа по токену, если они ещё есть в auth path, keychain restore path или provisioning path.
   - Проверить, как именно ваш сервер ожидает логин: только email+password, или ещё OIDC/QR как fallback.

3. **Синхронизировать onboarding и login flow с Android**
   - Перенести структуру экранов из Android-референса: onboarding, выбор способа входа, вход по почте, экран пароля, ошибки.
   - Сверить навигацию в [`AuthenticationFlowCoordinator.swift`](/Users/taus/Projects/arcana-ios/ElementX/Sources/FlowCoordinators/AuthenticationFlowCoordinator.swift) с тем, что реально нужно для Arcana.
   - Если QR/OIDC не нужны в вашем продукте, убрать их из основного пути, а не просто скрывать кнопки.

4. **Перенести собственные иконки и бренд-слой**
   - Собрать список иконок из Android-репозитория и сопоставить их с iOS asset catalog.
   - Обновить app icon и стартовый branding, сейчас в iOS уже есть [`ElementX/Resources/AppIcon.icon/Assets/AppIcon.png`](/Users/taus/Projects/arcana-ios/ElementX/Resources/AppIcon.icon/Assets/AppIcon.png), но это, вероятно, не ваш финальный arcana-набор.
   - Обновить стартовый логотип/mark в [`AuthenticationStartLogo.swift`](/Users/taus/Projects/arcana-ios/ElementX/Sources/Screens/Authentication/StartScreen/View/AuthenticationStartLogo.swift) и связанные view.
   - Проверить все экранные иконки, чтобы они соответствовали вашим Android-иконкам, а не дефолтному Matrix/Element оформлению.

5. **Обновить тексты и локализацию**
   - Новые английские строки добавлять в `Untranslated.strings`, не трогая `Localizable.strings`.
   - Переименовать тексты под email-login: labels, error messages, CTA, onboarding copy.
   - Если нужно, добавить iOS-only строки через `_ios` suffix по вашим правилам.

6. **Почистить тесты, превью и снапшоты**
   - Обновить unit tests для auth service, login VM, coordinator.
   - Обновить preview states и snapshot tests для onboarding/login/error states.
   - Проверить, что старые token/mxid-сценарии не остались в тестах как ложные ожидания.
   - Прогнать UI snapshots для ключевых состояний.

7. **Проверка на устройстве и финальная полировка**
   - Пройти полный флоу: старт, ввод email, выбор сервера если нужен, пароль, успешный вход.
   - Проверить ошибки: неверный email, неверный пароль, недоступный сервер, неподдерживаемый auth.
   - Посмотреть, как ведут себя push/restore/remember session после нового логина.

**Как я бы шёл по шагам**
1. Сначала делаю точный audit iOS vs Android и фиксирую целевой набор экранов.
2. Потом меняю auth/service слой, потому что он определяет всю остальную навигацию.
3. Потом переношу бренд и иконки.
4. Затем обновляю тексты и тесты.
5. В конце прогоняю сценарии и добиваю хвосты.

Если хочешь, следующим сообщением я могу уже превратить этот план в конкретный backlog по файлам: что именно трогать в iOS, что брать из Android, и в каком порядке безопаснее внедрять.
