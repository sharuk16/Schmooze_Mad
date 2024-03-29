//
//  Database.swift
//  Schmooze
//
//  Created by MAD2 on 6/2/22.
//

import Foundation
import FirebaseDatabase
import UIKit
import CoreMedia
import MessageKit
import CoreLocation

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress : String) -> String{
        
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        return safeEmail
        
    }   
}

extension DatabaseManager {
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child("\(path)").observeSingleEvent(of: .value){snapshot in
            guard let value = snapshot.value else {
                return
            }
            completion(.success(value))
        }
    }
}
       

// MARK: - Account Management
extension DatabaseManager{
    
    public func userExists(with email: String, completiton: @escaping ((Bool) -> Void))
    {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: {snapshot in
            guard snapshot.value as? String != nil else {
                completiton(false)
                return
            }
            completiton(true)
        })
    
    }
    
    
    ///Inserts new user to database
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool)-> Void) {
        database.child(user.safeEmail).setValue([
            "first_name" : user.firstName,
            "last_name" : user.lastName], withCompletionBlock: {error, _ in
                                                guard error == nil else {
            print("failed to write to database")
            completion(false)
            return
            }
                self.database.child("users").observeSingleEvent(of: .value, with: {snapshot in
                    if var usersCollection = snapshot.value as? [[String: String]] {
                        //append
                        let newElement = [
                            "name": user.firstName + " " + user.lastName,
                            "email": user.safeEmail ]
                        usersCollection.append(newElement)
                        
                        self.database.child("users").setValue(usersCollection, withCompletionBlock: {error, _ in guard error == nil else {
                            completion(false)
                            return
                        }
                            completion(true)
                        })
                    }
                    else {
                        //create dict
                        let newCollection : [[String: String]] = [
                            ["name": user.firstName + " " + user.lastName,
                             "email": user.safeEmail]]
                        self.database.child("users").setValue(newCollection, withCompletionBlock: {error, _ in guard error == nil else {
                            completion(false)
                            return
                        }
                            completion(true)
                        })
                    }
                })
                
        })
    }

    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        //get users
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    public enum DatabaseError: Error {
        case failedToFetch
    }
}

// send message
extension DatabaseManager {
    ///create new convo to user
    public func createNewConvo(with otherUserEmail: String, name: String, firstMessage: Message , completion: @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
        let currentName = UserDefaults.standard.value(forKey: "name") as? String else{
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("user not found")
                return
            }
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            switch firstMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            let conversationID = "conversation_\(firstMessage.messageId)"
            let newConvoData: [String: Any] = [
                "id": conversationID,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            let recipient_newConvoData: [String: Any] = [
                "id": conversationID,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            //update recipient convo
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    //append
                    conversations.append(recipient_newConvoData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConvoData])
                }
                else{
                    //create
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConvoData])
                }
            })
            
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                //convo array exists for user , append
                conversations.append(newConvoData)
                userNode["conversations"] = conversations
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreateConvo(name: name, conversationID: conversationID, firstMessage: firstMessage, completion: completion)
        
                })
            }
            else {
                //convo array doesnt exist, create
                userNode["conversations"] =  [
                    newConvoData
                ]
                
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreateConvo(name: name,conversationID: conversationID, firstMessage: firstMessage, completion: completion)
                })
            }
        })
    }
    
    private func finishCreateConvo(name: String, conversationID: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
//        {
//            "id": String,
//            "type": text, photo, video,
//            "content": String,
//            "date": Date(),
//            "sender_email": String,
//            "isRead": true/false,
//        }
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        var message = " "
        switch firstMessage.kind {
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        let collectionMessage: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentUserEmail,
            "is_read": false,
            "name": name]
        
        let value: [String: Any] = [
            "messages": [
                collectionMessage]
        ]
        database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    ///fetch and return all convo
    public func getAllConvo(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void){
        database.child("\(email)/conversations").observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let conversationsId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String:Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                          return nil
                }
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationsId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
        
    //get all message for specific convo
    public func getAllMessagesForConvo(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observeSingleEvent(of: .value, with: {snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else {
                          return nil
                      }
                var kind: MessageKind?
                if type == "location" {
                    let locationComponents = content.components(separatedBy: ",")
                    guard let longitude = Double(locationComponents[0]),
                          let latitude = Double(locationComponents[1]) else {
                              return nil
                          }
                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: CGSize(width: 300, height: 300))
                    kind = .location(location)
                }
                else {
                    kind = .text(content)
                }
                guard let finalKind = kind else {
                    return nil
                }
                
                let sender = Sender(senderId: senderEmail,
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: date,
                               kind: finalKind)
            })
            completion(.success(messages))
        })
    
}
    
    //sends message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message, completion: @escaping (Bool) -> Void) {
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard let strongSelf = self else {
                return
            }
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch newMessage.kind {
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }
            
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            let newMessageEntry: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentUserEmail,
                "is_read": false,
                "name": name
            ]
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) {error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                strongSelf.database.child("\(currentEmail)/convsersations").observeSingleEvent(of: .value, with: {snapshot in
                    guard var currentUserConvo = snapshot.value as? [[String:Any]] else {
                        completion(false)
                        return
                    }
                    
                    let updatedValue: [String:Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    var targetConversation: [String:Any]?
                    var position = 0
                    
                    for convoDic in currentUserConvo {
                        if let currentId = convoDic["id"] as? String, currentId == conversation {
                        targetConversation = convoDic
                        break
                        }
                        
                        position += 1
                    }
                    targetConversation?["latest_message"] = updatedValue
                    guard let finalConvo = targetConversation else {
                        
                        completion(false)
                        return
                    }

                    currentUserConvo[position] = finalConvo
                    strongSelf.database.child("\(currentEmail)/convsersations").setValue(currentUserConvo, withCompletionBlock: {error, _ in
                        guard error == nil else  {
                            completion(false)
                            return
                        }
                        //update for other user
                        strongSelf.database.child("\(otherUserEmail)/convsersations").observeSingleEvent(of: .value, with: {snapshot in
                            guard var otherUserConvo = snapshot.value as? [[String:Any]] else {
                                completion(false)
                                return
                            }
                            
                            let updatedValue: [String:Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message
                            ]
                            var targetConversation: [String:Any]?
                            var position = 0
                            
                            for convoDic in otherUserConvo {
                                if let currentId = convoDic["id"] as? String, currentId == conversation {
                                targetConversation = convoDic
                                break
                                }
                                
                                position += 1
                            }
                            targetConversation?["latest_message"] = updatedValue
                            guard let finalConvo = targetConversation else {
                                
                                completion(false)
                                return
                            }

                            otherUserConvo[position] = finalConvo
                            strongSelf.database.child("\(otherUserEmail)/convsersations").setValue(otherUserConvo, withCompletionBlock: {error, _ in
                                guard error == nil else  {
                                    completion(false)
                                    return
                                }
                                completion(true)
                            })
                        })
                    })
                })
               
            }
        })
    }
    public func deleteConvo(conversationId: String, completion: @escaping (Bool)-> Void){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value, with: {snapshot in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations {
                    if let id = conversation["id"] as? String,
                       id == conversationId {
                        print("convo found to deleted")
                        break
                    }
                    positionToRemove += 1
                }
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations, withCompletionBlock: {error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    print("convo deleted")
                    completion(true)
                })
            }
        })
    }
}
                                                                    

    
struct ChatAppUser {
    let firstName : String
    let lastName : String
    let emailAddress: String
    
    var safeEmail: String{
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
        
    }
}

