Airline Management 项目结构（按“文件 + 内容/职责”放在一起的版本）

res://
├── data/
│   ├── cities.json
│   │   内容：
│   │   - 城市静态数据
│   │   - 每个城市至少包含：id、坐标（x, y）、规模/等级等
│   │   用途：
│   │   - 给地图画城市点
│   │   - 给距离系统、航程系统、乘客生成系统提供基础城市信息
│   │   特点：
│   │   - 纯静态，只读
│   │
│   ├── aircraft_models.json
│   │   内容：
│   │   - 飞机型号静态数据
│   │   - 每个机型至少包含：id、speed、capacity、max_range 等
│   │   用途：
│   │   - 决定飞机速度、载客量、航程
│   │   - 给飞行系统、可达城市系统、机场面板显示用
│   │   特点：
│   │   - 纯静态，只读
│
├── systems/
│   ├── game_world.gd
│   │   内容：
│   │   - 整个游戏当前世界状态
│   │   - cities：运行时使用的城市对象集合
│   │   - aircraft_models：运行时使用的机型对象集合
│   │   - passengers：当前世界里的所有乘客
│   │   - aircrafts：当前世界里的所有飞机
│   │   - 后续应继续放：money、finance_logs、world_time（如果采用世界时间）
│   │   用途：
│   │   - 作为唯一真实状态来源
│   │   - 所有系统都只读写这一份 world
│   │
│   ├── data_loader.gd
│   │   内容：
│   │   - 从 cities.json、aircraft_models.json 读取数据
│   │   - 把静态 json 转成游戏里可用的对象/字典
│   │   用途：
│   │   - 初始化 GameWorld
│   │
│   ├── world_tick_system.gd
│   │   内容：
│   │   - 游戏主更新循环
│   │   - 每次 tick 调用各个系统推进世界
│   │   用途：
│   │   - 相当于总调度器
│   │   - 谁负责“每一帧/每一拍更新世界”，就是它
│   │
│   ├── flight_system.gd
│   │   内容：
│   │   - 飞机开始飞行
│   │   - 飞机切换城市
│   │   - 航线启动/飞行状态切换
│   │   用途：
│   │   - 定义“飞行”这件事本身怎么开始、怎么落地
│   │
│   ├── flight_execution_system.gd
│   │   内容：
│   │   - 计算飞行中飞机的位置进度
│   │   - 判断是否到站
│   │   - 处理 in_flight / grounded / stopover_pause 等状态
│   │   用途：
│   │   - 这是飞行推进核心
│   │   - 地图上飞机怎么移动、逻辑上什么时候到达，核心都在这里
│   │   当前项目最关键的问题点也在这里
│   │
│   ├── settlement_system.gd
│   │   内容：
│   │   - 到站后的收益计算
│   │   - 根据乘客当前这一段路程，计算收入
│   │   - 再减去油费，得出本段结算结果
│   │   用途：
│   │   - 负责“这趟飞行赚多少钱”
│   │   备注：
│   │   - 现在如果重开项目，建议它只负责“算数”
│   │   - 真正记账统一交给 GameWorld 的 finance 方法
│   │
│   ├── fuel_cost_system.gd
│   │   内容：
│   │   - 按城市距离、机型参数等计算燃油成本
│   │   用途：
│   │   - 给 settlement 或财务系统提供油费数值
│   │
│   ├── unloading_system.gd
│   │   内容：
│   │   - 飞机到站后，乘客下机
│   │   - 更新乘客状态：arrived / waiting / transfer 等
│   │   用途：
│   │   - 负责“人怎么从飞机上回到城市里”
│   │
│   ├── boarding_system.gd
│   │   内容：
│   │   - 乘客登机
│   │   - 乘客下机（手动或逻辑操作）
│   │   用途：
│   │   - 负责机场面板里的乘客装卸逻辑
│   │
│   ├── passenger_generator.gd
│   │   内容：
│   │   - 生成乘客
│   │   - 给乘客生成路线、票价、初始等待时间
│   │   用途：
│   │   - 负责需求产生
│   │
│   ├── passenger_spawn_system.gd
│   │   内容：
│   │   - 把乘客真正加入世界
│   │   用途：
│   │   - 负责“什么时候生成乘客”
│   │
│   ├── passenger_decay_system.gd
│   │   内容：
│   │   - 检查等待太久的乘客是否离开世界
│   │   - 区分 initial、transfer 等不同等待上限
│   │   用途：
│   │   - 防止机场乘客无限堆积
│   │
│   ├── reachable_city_system.gd
│   │   内容：
│   │   - 根据飞机当前城市、机型航程，算它能飞到哪些城市
│   │   用途：
│   │   - 给选航线、机场界面、合法目的地判断使用
│   │
│   ├── distance_system.gd
│   │   内容：
│   │   - 计算城市之间距离
│   │   用途：
│   │   - 给飞行时间、油费、可达范围、乘客票价提供基础距离
│   │
│   ├── route_planner.gd
│   │   内容：
│   │   - 给乘客规划路线
│   │   - 目前是简单直达/一次中转
│   │   用途：
│   │   - 负责乘客“想去哪里、怎么去”
│   │
│   ├── route_profit_system.gd
│   │   内容：
│   │   - 计算某条路线值不值得飞
│   │   用途：
│   │   - 后续可用于 AI 决策、玩家辅助分析
│   │
│   ├── flight_start_system.gd
│   │   内容：
│   │   - 起飞前检查
│   │   用途：
│   │   - 把“能不能开始这一段飞行”的逻辑单独拆出
│   │
│   ├── flight_economy_system.gd
│   │   内容：
│   │   - 飞行相关经济计算
│   │   用途：
│   │   - 现在可与 settlement/fuel 有部分重叠，重开时要明确定义边界
│   │
│   ├── visible_passenger_system.gd
│   │   内容：
│   │   - 当前机场/当前飞机应该显示哪些乘客
│   │   用途：
│   │   - 给 UI 做展示筛选
│   │
│   └── boarding / settlement / unloading / fuel / distance 这一批系统的原则
│       内容：
│       - 只处理规则
│       - 不碰 UI
│       - 不自己保存第二份状态
│       用途：
│       - 保证结构干净
│
├── scripts/
│   ├── city.gd
│   │   内容：
│   │   - 单个城市对象
│   │   - 城市运行时属性
│   │   用途：
│   │   - 从 json 读出来后，在世界里作为 city 实例使用
│   │
│   ├── aircraft_model.gd
│   │   内容：
│   │   - 单个机型对象
│   │   - 机型参数：速度、容量、航程等
│   │   用途：
│   │   - 飞机实例会引用 model_id 对应的机型
│   │
│   ├── aircraft.gd
│   │   内容：
│   │   - 单架飞机对象
│   │   - 至少包含：id、model_id、current_city_id、operation_state、
│   │     active_route、segment_from_city_id、segment_to_city_id、
│   │     segment_start_time、segment_end_time、onboard_passenger_ids
│   │   用途：
│   │   - 是飞行系统的主要状态对象
│   │
│   ├── passenger.gd
│   │   内容：
│   │   - 单个乘客对象
│   │   - 路线、当前段目标、票价、状态、当前所在城市、是否在机上
│   │   用途：
│   │   - 是客流系统的主要状态对象
│
├── ui/
│   ├── world_map.tscn / world_map.gd
│   │   内容：
│   │   - 世界地图主界面
│   │   - 显示城市点、航线、飞机位置
│   │   - 响应点击城市、打开机场面板、选择航线
│   │   用途：
│   │   - 这是玩家在主游戏里看到的总览地图
│   │   原则：
│   │   - 只负责显示和交互
│   │   - 不应该自己拥有第二份飞行逻辑
│   │   - 最理想状态是：它只读取飞行系统算好的状态/进度
│   │
│   ├── airport_panel.tscn / airport_panel.gd
│   │   内容：
│   │   - 某个机场的详细界面
│   │   - 显示该机场的飞机
│   │   - 显示该机场可装载乘客
│   │   - 允许选飞机、装乘客、进入出发流程
│   │   用途：
│   │   - 这是机场操作页
│   │   原则：
│   │   - 只显示“当前停在这个机场的 grounded 飞机”
│   │   - 不应该自己重新发明飞行状态
│   │
│   ├── aircraft_panel.gd
│   │   内容：
│   │   - 飞机详细信息显示
│   │   - 可能包含飞机载客信息、状态信息
│   │   用途：
│   │   - 作为机场页中的飞机子面板
│   │
│   ├── finance_panel.tscn / finance_panel.gd（后续建议独立保留）
│   │   内容：
│   │   - 资金页面
│   │   - 显示当前余额
│   │   - 显示流水记录
│   │   用途：
│   │   - 给玩家看经营结果
│   │   原则：
│   │   - 只读 GameWorld.money 和 GameWorld.finance_logs
│   │   - 不允许自己维护第二份财务数据
│
├── scenes/
│   ├── main_game.tscn / main_game.gd
│   │   内容：
│   │   - 主场景
│   │   - 创建 GameWorld
│   │   - 初始化数据
│   │   - 创建初始飞机
│   │   - 把 GameWorld 交给 WorldMap
│   │   - 在 _process 中调用 WorldTickSystem.update(...)
│   │   用途：
│   │   - 这是整个游戏真正的启动入口
│   │
│   ├── test_simulation.tscn / test_simulation.gd
│   │   内容：
│   │   - 测试飞行/世界推进用的测试场景
│   │   用途：
│   │   - 只用于测试，不属于正式主流程
│   │
│   ├── test_airport_panel.tscn / test_airport_panel.gd
│   │   内容：
│   │   - 单独测试机场面板的场景
│   │   用途：
│   │   - 只用于测试，不属于正式主流程
│
└── 结构总原则
	1. Data 只存静态数据，不改。
	2. GameWorld 是唯一真实状态来源，整个游戏只有一份。
	3. Systems 只修改 GameWorld，不碰 UI。
	4. UI 只显示和交互，不保存第二份业务状态。
	5. MainGame 只负责初始化 world 和驱动 tick。
	6. 飞机位置、飞行进度、到站判定必须来自同一套逻辑，不能地图一套、系统一套。
	7. 机场面板显示飞机时，只看 current_city_id 和 operation_state，不看历史字段。
	8. 财务页只读统一账本，不自己记账。