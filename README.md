这里实现了一个叫做 group 的模块，示范如何在同一个 skynet 进程内运行多组游戏服务器。

group 模块中有 7 个 API ，分别为：

* group.start 实现一个 group 框架下的服务的简单框架。
* group.call 在 group 内发起一个跨服务调用。
* group.send 发送一条消息到 group 内的另一个服务。
* group.newservice 在 group 内启动一个新服务(同名服务可启动多次)。
* group.newgroup 启动一个新的 group 。
* group.query 查询 group 内一个名字对应的服务(如果没有同名服务，则启动唯一一份)。
* group.name 查询当前 group 的名字。

下面分别介绍这些 API 的用法，以及如何使用这个 group 模块。

当我们需要启动多组游戏服务器时，阻止我们把多组服务器运行在同一个 skynet 进程中最重要理由是，我们设计了一些一些具名服务，比如 "dbserver" ，"loginserver" ，"gateserver" 等等。而无论是 skynet 内核带的给服务命名的手段，还是用 skynet.uniqueservice 去启动具名服务，都无法有效的按游戏（运营需求上的）服务器隔离。为了贪图方便，往往会为每个游戏服务器单独启动一个 skynet 进程。

但解决这个问题的方法其实非常简单：开发一个以 group 为单位隔离的服务名字管理模块。只要所有服务都通过这个模块管理名字，那么在同一个 skynet 进程中就可以方便的启动多个 group 组，每个组下的服务都相互不相关。

我们可以开发一个组（服务器）管理服务，使用 group.newgroup(groupname, bootservice) 这个 API 就可以启动一个新的组。可以为这个组设置一个 groupname ，这个只是一个备注，并没有什么实际的含义，多个组同名也没有关系。协调组名的工作可由这个管理服务来做。这个 API 的第 2 个参数是这个组的启动器，类似 skynet 在 config 里配置的启动服务一样。新的组建立后，会在这个组里面启动第一个服务，就是 bootservice ，之后的启动工作应该由它来完成。group.newgroup 会在 bootservice 的启动流程结束后关闭它。

group.newservice(name, ...) 用来取代 skynet.newservice 。当一个服务调用 group.newservice 后，会在同组内启动一个新的 service ，并会自动为这个服务命名为 name 。当同一个名字的服务被启动多份，后面启动的服务将没有名字，但 group.newservice 返回的地址依然是有效的。

group.query(name) 可以在当前组内查询一个名字对应的地址，这个 API 多用于管理器，或只需要启动同名服务一次。group.call 和 group.send 都支持直接传入字符串名字，而并不需要先查询。

group.call(name, ...) 相当于 skynet.call(name, "lua", ...) 。区别在于，当 name 是一个字符串时，它指当前组内服务的名字。这个名字是由 group.newservice 创建出来的。如果之前并未访问过这个服务，那么在 call 之前，会多一个查询名字的过程。

group.send(name, ...) 相当于 skynet.send(name, "lua", ...)。和 group.call 一样，name 可以指当前组内服务的名字。虽然，这个 api 可能需要选查询一下名字对应的地址，但 api 并不会阻塞（和 skynet.send 行为一致），它会将向未知名字发送的消息放在一个待发队列中。

group.start(config) 取代了 skynet.start 的功能，用于服务初始化。但用起来更为简单，config 是一张表，里面可以填写下列数据。

config.service = { "service1", "service2" , ... }  可以给出一张 service 表，在服务初始化的阶段就去查询一系列的服务，等待这些服务启动完毕再初始化自己。这样显示的描述出依赖的服务，可以使初始化流程更明确。这张表是可选的，如果并没有在表内列出依赖的服务，那么在运行期间访问某个服务，需要先查询名字对应的地址。

config.init = function (...) end 这个是一个可选的初始化过程，可以接收到 group.newservice 传过来的参数。和传统的 skynet.newservice 不同，启动参数可以是任意 lua 类型，而不仅仅是字符串。

config.command = { cmd = function(...) end } 传入一组消息处理函数。group 模块约定，所有消息请求都是以 lua 协议传递，第一个字符串参数是请求的消息名字，这里可以根据这个名字来定义一组函数处理外部请求。注意，名字不能以 _ 开头（保留给内部使用）。为了简化处理，这里并没有严格区分 send 推送消息（不需要回应）和 call 请求消息（需要回应）。框架根据 session 来决定是否将消息处理函数的返回值发送给请求方。

----

examples 目录下有一个非常简单的范例。

groupmain 是总的启动文件，它启动了三个组。每个组的启动文件都是 group_start 。

当一个组启动后，它会启动一个 echoserver 服务。并尝试向 echoserver 发送一条消息。

groupmain 里还演示了一个简单的管理特性，可以去组管理服务查询该组中当前的所有服务列表。在实际开发应用中，可以扩展这些管理特性。






