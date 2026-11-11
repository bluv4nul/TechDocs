# Наполнение Redmine для лабораторной "Alien Invasion".
# Запуск (из папки WikiAlien):
#   docker compose cp redmine-seed.rb redmine:/tmp/seed.rb
#   docker compose exec -T redmine sh -c 'SECRET_KEY_BASE=$REDMINE_SECRET_KEY_BASE RAILS_ENV=production bundle exec rails runner /tmp/seed.rb'
# Скрипт можно запускать повторно: существующие записи не дублируются.

Setting.default_language = 'ru'
Redmine::DefaultData::Loader.load('ru') if Redmine::DefaultData::Loader.no_data?

admin = User.find_by!(login: 'admin')
admin.update_columns(language: 'ru')
User.current = admin

feature = Tracker.find_by(name: 'Фича') || Tracker.find_by!(name: 'Улучшение')
feature.update!(name: 'Фича')
bug = Tracker.find_by!(name: 'Ошибка')

project = Project.find_by(identifier: 'alien-invasion-game') || Project.new(identifier: 'alien-invasion-game')
project.name = 'Alien Invasion Game'
project.description = "2D-аркада на Python и Pygame: корабль игрока отбивается от флота пришельцев.\n\n" \
                      "Требования описаны в SRS, устройство игры - в SDD (Wiki.js, раздел alien-invasion)."
project.is_public = false
project.enabled_module_names = %w[issue_tracking wiki gantt calendar]
project.trackers = [feature, bug]
project.save!

manager = Role.find_by!(name: 'Менеджер')
unless Member.exists?(project: project, user: admin)
  Member.create!(project: project, user: admin, roles: [manager])
end

v10 = Version.find_or_create_by!(project: project, name: '1.0 Базовая версия') do |v|
  v.description = 'Корабль, стрельба, флот пришельцев, очки, окончание игры'
end
v11 = Version.find_or_create_by!(project: project, name: '1.1 Интерфейс и доработки') do |v|
  v.description = 'Кнопка Play, панель счета, уровни, жизни на экране, Game Over'
end

normal = IssuePriority.find_by!(name: 'Нормальный')
high   = IssuePriority.find_by!(name: 'Высокий')
low    = IssuePriority.find_by!(name: 'Низкий')

issues = [
  [feature, high, v10, 2, 'Создать главный класс игры AlienInvasion и окно Pygame',
   "Файл alien_invasion.py. Класс AlienInvasion инициализирует Pygame, создает окно 1280x720 с заголовком \"Alien Invasion\" и запускает основной цикл run_game().\n\n" \
   "Готово, когда: python alien_invasion.py открывает пустое окно, которое закрывается крестиком."],
  [feature, high, v10, 1, 'Создать класс Settings для хранения всех настроек',
   "Файл settings.py. В классе Settings лежат размер окна, цвет фона, параметры снаряда, число жизней, скорости и коэффициенты ускорения. Остальные классы читают значения только отсюда.\n\n" \
   "Готово, когда: в коде игры нет числовых констант вне settings.py."],
  [feature, high, v10, 2, 'Создать класс Ship и отобразить корабль на экране',
   "Файл ship.py. Класс Ship загружает images/spaceship.bmp и ставит корабль по центру нижнего края окна. Метод blitme() рисует корабль.\n\n" \
   "Связано с: FR-1.\nГотово, когда: корабль виден внизу по центру."],
  [feature, high, v10, 2, 'Реализовать непрерывное движение корабля влево и вправо по нажатию клавиш',
   "Флаги moving_left и moving_right выставляются по KEYDOWN и снимаются по KEYUP (стрелки, A и D). Ship.update() сдвигает корабль на ship_speed_factor за кадр и не выпускает его за края окна.\n\n" \
   "Связано с: FR-1, UI-1.\nГотово, когда: при удержании клавиши корабль едет плавно и останавливается у края."],
  [feature, high, v10, 3, 'Создать класс Bullet и реализовать стрельбу по нажатию на пробел',
   "Файл bullet.py. Снаряд - прямоугольник 10x18, появляется у носа корабля и летит вверх. На экране одновременно не больше bullets_allowed снарядов (6). Снаряды, вылетевшие за верхний край, удаляются из группы.\n\n" \
   "Связано с: FR-2.\nГотово, когда: пробел выпускает снаряд, седьмой снаряд не появляется, пока не исчез один из шести."],
  [feature, normal, v10, 1, 'Создать класс Alien и вывести одного пришельца на экран',
   "Файл alien.py. Класс Alien наследует pygame.sprite.Sprite, загружает images/alien.bmp и появляется у левого верхнего угла с отступом в свой размер.\n\n" \
   "Связано с: FR-3.\nГотово, когда: один пришелец виден в левом верхнем углу."],
  [feature, normal, v10, 3, 'Создать флот пришельцев, заполнив ими экран',
   "Метод _create_fleet() считает, сколько пришельцев помещается в ряд (шаг - две ширины спрайта) и сколько рядов влезает над кораблем, но не больше трех. Пришельцы хранятся в pygame.sprite.Group.\n\n" \
   "Связано с: FR-3.\nГотово, когда: на экране три ровных ряда пришельцев с отступами от краев."],
  [feature, normal, v10, 3, 'Реализовать движение флота пришельцев вправо/влево и вниз',
   "Alien.update() сдвигает пришельца на alien_speed_factor * fleet_direction. Если хотя бы один пришелец коснулся края, весь флот опускается на fleet_drop_speed (12 пикселей) и меняет направление.\n\n" \
   "Связано с: FR-3.\nГотово, когда: флот ходит от края к краю и после каждого разворота оказывается ниже."],
  [feature, high, v10, 2, 'Реализовать механику уничтожения пришельцев при попадании пули',
   "pygame.sprite.groupcollide(bullets, aliens, True, True) удаляет и снаряд, и пришельца. Когда пришельцев не осталось, снаряды очищаются и создается новый флот.\n\n" \
   "Связано с: FR-4, FR-5.\nГотово, когда: попадание убирает пришельца, после последнего появляется новая волна."],
  [feature, normal, v10, 2, 'Создать класс GameStats и реализовать подсчет очков за сбитых пришельцев',
   "Файл game_stats.py. GameStats хранит score, high_score, level, ships_left и признак game_active. За каждого сбитого пришельца начисляется alien_points (50 на первом уровне); если один снаряд задел нескольких, считаются все.\n\n" \
   "Связано с: FR-4.\nГотово, когда: счет растет на 50 за каждого пришельца первой волны."],
  [feature, high, v10, 3, 'Реализовать потерю корабля и окончание игры при столкновении пришельца с кораблем',
   "Столкновение пришельца с кораблем (spritecollideany) и выход пришельца на нижнюю границу обрабатываются одинаково, методом _ship_hit(): минус одна жизнь, поле очищается, создается новый флот, корабль возвращается в центр, пауза 0,5 с. Когда жизней не осталось, game_active = False.\n\n" \
   "Связано с: FR-6, FR-7.\nГотово, когда: после потери последнего корабля игра останавливается."],
  [feature, normal, v11, 2, 'Создать класс Button и запуск игры по кнопке Play',
   "Файл button.py. Кнопка 200x50 по центру экрана видна, пока игра неактивна. Щелчок левой кнопкой мыши по ней сбрасывает статистику и скорости, создает новый флот и скрывает курсор.\n\n" \
   "Связано с: FR-9.\nГотово, когда: игра стартует и перезапускается только по кнопке Play."],
  [feature, normal, v11, 2, 'Создать класс Scoreboard и вывести счет, рекорд и уровень',
   "Файл scoreboard.py. Счет справа вверху, рекорд по центру вверху, уровень под счетом. Текст перерисовывается в изображение только при изменении значения.\n\n" \
   "Связано с: FR-8.\nГотово, когда: три числа видны во время игры и обновляются сразу после попадания."],
  [feature, normal, v11, 2, 'Реализовать уровни: ускорение игры после уничтожения флота',
   "После каждой уничтоженной волны Settings.increase_speed() умножает скорости корабля, снарядов и пришельцев на 1,1, цену пришельца - на 1,5, уровень растет на 1. При новой игре значения возвращаются к начальным.\n\n" \
   "Связано с: FR-5.\nГотово, когда: на втором уровне пришелец стоит 75 очков и флот движется заметно быстрее."],
  [feature, normal, v11, 2, 'Показать на экране количество оставшихся кораблей',
   "Сейчас число жизней хранится в GameStats.ships_left, но игрок его не видит. Нужно вывести в левом верхнем углу по иконке корабля на каждую оставшуюся жизнь.\n\n" \
   "Связано с: FR-8.\nГотово, когда: после потери корабля одна иконка исчезает."],
  [feature, low, v11, 2, 'Добавить экран Game Over',
   "Сейчас после потери последнего корабля поверх застывшего поля просто появляется кнопка Play. Нужна надпись \"Game Over\" и итоговый счет над кнопкой.\n\n" \
   "Связано с: FR-7, раздел 5.2 SDD.\nГотово, когда: проигрыш можно отличить от стартового экрана."],
  [feature, low, v11, 1, 'Ограничить частоту кадров до 60 FPS',
   "В основном цикле нет pygame.time.Clock, поэтому скорость игры зависит от мощности компьютера. Добавить clock.tick(60) в run_game().\n\n" \
   "Связано с: NFR-1.\nГотово, когда: скорость флота одинакова на разных машинах."],
  [bug, normal, v11, 1, 'Счет рисуется в левом верхнем углу вместо правого',
   "Шаги: запустить игру, сбить пришельца.\nОжидается: счет справа вверху, как рассчитано в prep_score().\nФактически: счет в левом верхнем углу.\n\n" \
   "Причина: в Scoreboard.show_score() изображение счета выводится по self.screen_rect вместо self.score_rect (scoreboard.py, строка 37).\nСвязано с: FR-8."]
]

start = Date.new(2026, 11, 11)
issues.each do |tracker, priority, version, hours, subject, description|
  issue = Issue.find_by(project: project, subject: subject) || Issue.new(project: project, subject: subject)
  issue.tracker = tracker
  issue.author ||= admin
  issue.assigned_to = admin
  issue.priority = priority
  issue.fixed_version = version
  issue.estimated_hours = hours
  issue.description = description
  issue.start_date ||= start
  issue.save!
end

puts "Проект: #{project.name} (#{project.identifier})"
puts "Задач: #{project.issues.count}, из них Фича: #{project.issues.where(tracker: feature).count}, Ошибка: #{project.issues.where(tracker: bug).count}"
puts "Назначено на #{admin.login}: #{project.issues.where(assigned_to_id: admin.id).count}"
