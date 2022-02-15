//
//  ChatViewController.swift
//  Schmooze
//
//  Created by MAD2 on 6/2/22.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SwiftUI
import CoreLocation

struct Message: MessageType{
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}
struct Location: LocationItem {
    var location: CLLocation
    
    var size: CGSize
}

extension MessageKind {
    var messageKindString: String {
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .custom(_):
            return "custom"
        case .linkPreview(_):
            return "link_preview"
        }
    }
}

struct Sender: SenderType{
    public var senderId: String
    public var displayName: String
}



class ChatViewController: MessagesViewController {
    public let otherUserEmail: String
    private let conversationId: String?

    public var isNewConvo = false
    
    private var messages = [Message]()
    
    private var selfSender: Sender?  {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        return  Sender(senderId: safeEmail,
                       displayName: "Me")
    }
    
    public static let dateFormatter: DateFormatter = {
        let formattre = DateFormatter()
        formattre.dateStyle = .medium
        formattre.timeStyle = .long
        formattre.locale = .current
        return formattre
    }()
    
    
    
    init(with email: String, id: String?) {
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
        if let conversationId = conversationId {
            listenForMsg(id: conversationId, shouldScrollToBottom: true)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .red
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
        
        
    }
    private func setupInputButton(){
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    
    private func presentInputActionSheet(){
        let actionSheet = UIAlertController(title: "Menu", message: "What do you like to send?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: {[weak self] _ in
            self?.presentLocationPicker()
        }))
        present(actionSheet, animated: true)
    }
    private func presentLocationPicker() {
        let vc = LocationPickerViewController()
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = {[weak self] selectedCoordinates in
            guard let strongSelf = self else {
                return
            }
            guard let messageId = strongSelf.createMessageId(),
                  let conversationId = strongSelf.conversationId,
                  let name = strongSelf.title,
                  let selfSender = strongSelf.selfSender else {
                      return
                  }
            let longitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            print("long = \(longitude) | lat = \(latitude)")
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: .zero)
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(location))
            
                DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: {success in
                    
                    if success {
                        print("location sent")
                    }
                    else {
                        print("failed to send location")
                    }
                })
            
        }
        navigationController?.pushViewController(vc, animated: true)
    }
            
    private func listenForMsg(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConvo(with: id, completion: { [weak self] result in
            switch result {
            case .success(let messages):
                print("got msg successfully: \(messages)")
                guard !messages.isEmpty else {
                    print("messages are empty")
                    return
                }
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                }
            case .failure(let error):
                print("failed to get messages: \(error)")
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: " ").isEmpty,
        let selfSender = self.selfSender,
        let messageId = createMessageId() else {
                  return
        }
        
        print("sending: \(text)")
        //send message here
        let mmessage = Message(sender: selfSender,
                               messageId: messageId,
                               sentDate: Date(),
                               kind: .text(text))
        if isNewConvo {
            
            DatabaseManager.shared.createNewConvo(with: otherUserEmail, name: self.title ?? "user", firstMessage: mmessage, completion: { [weak self] success in
                if success {
                    print("message sent")
                    self?.isNewConvo = false
                }
                else {
                    print("failed to send")
                }
            })
        }
        else {
            //join existing convo
            guard let conversationId = conversationId, let name = self.title  else {
                return
            }
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: mmessage, completion: {success in
                if success {
                    print("message sent")
                }
                else{
                    print("failed to send message")
                }
            })
        }
    }
    
    private func createMessageId() -> String? {
        //
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email")as? String else {
            return nil
        }
        
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        print("Created message id: \(newIdentifier)")
        return newIdentifier
    }
}
extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    
    
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Error cacheing")
    }
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
}
              
