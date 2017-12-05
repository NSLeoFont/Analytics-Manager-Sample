
import UIKit
import CloudKit

/*:
  
 The way we're going to setup our analytics system is that we're going to start with an AnalyticsManager. This class will act as the top level API for logging events, and an instance of this class will be dependency injected into any view controller that wants to use our system.
 
 But our AnalyticsManager won't actually do any logging. Instead it will use an AnalyticsEngine to send events to a backend. AnalyticsEngine will be a protocol that we can have multiple implementations of (for example one for testing, one for staging and one for production). It will also make it easier to switch out any third party SDK we might be using in the future.
 
 Finally, we'll have an enum called AnalyticsEvent, which will contain all the events that our analytics system supports.
 
 */


enum LoginFailureReason {
    case wrongPassword
    case userDoesNotExist
    case userNonActivated
    //etc
}


enum AnalyticsEvent {
    case loginScreenViewed
    case loginAttempted
    case loginFailed(reason: LoginFailureReason)
    case loginSucceeded
    case messageListViewed
    case messageSelected(index: Int)
    case messageDeleted(index: Int, read: Bool)
}

protocol AnalyticsEngine: class {
    func sendAnalyticsEvent(named name: String, metadata: [String : String])
}

/*:
 The beauty of this setup is that it enables multiple implementations of the AnalyticsEngine protocol. For example, we can get started with a simple CloudKit based one:
 */

final class CloudKitAnalyticsEngine: AnalyticsEngine {
    private let database: CKDatabase
    
    init(database: CKDatabase = CKContainer.default().publicCloudDatabase) {
        self.database = database
    }
    
    func sendAnalyticsEvent(named name: String, metadata: [String : String]) {
        let record = CKRecord(recordType: "AnalyticsEvent.\(name)")
        
        for (key, value) in metadata {
            record[key] = value as NSString
        }
        
        database.save(record) { _, _ in
            // We treat this as a fire-and-forget type operation
        }
    }
}

/*:
 
 Or we could use more advanced solutions like sending data to our own backend database, or using third party SDKs
 
 Let's take a look at how we can serialize an AnalyticsEvent value to prepare it for consumption by an AnalyticsEngine.
 */

extension AnalyticsEvent {
    var name: String {
        switch self {
        case .loginScreenViewed, .loginAttempted,
             .loginSucceeded, .messageListViewed:
            return String(describing: self)
        case .loginFailed:
            return "loginFailed"
        case .messageSelected:
            return "messageSelected"
        case .messageDeleted:
            return "messageDeleted"
        }
    }
}

extension AnalyticsEvent {
    var metadata: [String : String] {
        switch self {
        case .loginScreenViewed, .loginAttempted,
             .loginSucceeded, .messageListViewed:
            return [:]
        case .loginFailed(let reason):
            return ["reason" : String(describing: reason)]
        case .messageSelected(let index):
            return ["index" : "\(index)"]
        case .messageDeleted(let index, let read):
            return ["index" : "\(index)", "read": "\(read)"]
        }
    }
}

final class AnalyticsManager {
    private let engine: AnalyticsEngine
    
    init(engine: AnalyticsEngine) {
        self.engine = engine
    }
    
    func log(_ event: AnalyticsEvent) {
        engine.sendAnalyticsEvent(named: event.name, metadata: event.metadata)
    }
}


final class MessageCollection {
    
    func delete(at index: Int) -> Message {
        return Message()
    }
}

final class Message {
    var read: Bool!
}

final class MessageListViewController: UIViewController {
    private let messages: MessageCollection
    private let analytics: AnalyticsManager
    
    init(messages: MessageCollection, analytics: AnalyticsManager) {
        self.messages = messages
        self.analytics = analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        analytics.log(.messageListViewed)
    }
    
    private func deleteMessage(at index: Int) {
        let message = messages.delete(at: index)
        analytics.log(.messageDeleted(index: index, read: message.read))
    }
}

/*:
 
 We can now easily log events from any view controller. Just inject an AnalyticsManager and use one line of code to log any event.
 Using various implementations of AnalyticsEngine we can support multiple backends or third party SDKs.
 Since AnalyticsEngine is a protocol it's very easy to mock it in tests.
 Since AnalyticsEvent is a type safe enum, it adds an extra level of security for us and we can utilize the compiler to make sure that our setup is correct.
 
 Using three distinct parts, a manager, an engine and an event enum, we are now able to easily write predictable and flexible analytics code that is heavily compile time checked.
 
 */
