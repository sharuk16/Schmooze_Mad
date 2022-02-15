//
//  ViewController.swift
//  Schmooze
//
//  Created by MAD2 on 6/2/22.
//

import UIKit
import JGProgressHUD
import FirebaseAuth
import AVFAudio
import CoreLocation

struct Conversation {
    let id: String
    let name: String
    let otherUserEmail: String
    let latestMessage: LatestMessage
}
struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
}


class ConvoViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()
    
    private let tableVIew: UITableView = {
      let table = UITableView()
        table.isHidden = true
     // table.translatesAutoresizingMaskIntoConstraints = false
        table.register(ConvoTableViewCell.self, forCellReuseIdentifier: ConvoTableViewCell.identifier)
        return table
    }()
    
    private let noConvoLabel: UILabel = {
      let label = UILabel()
        label.text = "Start a convo"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
        
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapComposeButton))
        view.addSubview(tableVIew)
        view.addSubview(noConvoLabel)
        setupTableView()
        fetchConvo()
        startListeningForConvo()
        
//              NSLayoutConstraint.activate([
//                tableVIew.topAnchor.constraint(equalTo: view.topAnchor),
//                tableVIew.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//                tableVIew.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//                tableVIew.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//              ])
        
        
        
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableVIew.frame = view.bounds
    }
    
    private func startListeningForConvo() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else  {
            return
        }
        print("fetching convo...")
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConvo(for: safeEmail) { [weak self] result in
            switch result {
            case .success(let conversations):
                print("fetched convo model successuly")
                guard !conversations.isEmpty else {
                    return
                }
                self?.conversations = conversations
                
                DispatchQueue.main.async {
                    self?.tableVIew.reloadData()
                }
            case .failure(let error):
                print("failed to fetch convo \(error)")
            }
        }
    }
    
    @objc private func didTapComposeButton(){
        let vc = NewChatViewController()
        vc.completion = { [ weak self] result in
            self?.createNewConvo(result: result)
        }
        let navVC = UINavigationController(rootViewController: vc )
        present(navVC, animated: true)
        
    }
            
    private func createNewConvo(result: [String: String]){
            guard let name = result["name"],
                  let email = result ["email"] else {
                      return
                  }
            let vc = ChatViewController(with: email, id: nil)
            vc.isNewConvo = true
            vc.title = name
            vc.navigationItem.largeTitleDisplayMode = .never
            navigationController?.pushViewController(vc, animated: true)
        
            }
    
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    startListeningForConvo()
  }
  
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
    }
  
  
    private func validateAuth(){
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            let nav = UINavigationController(rootViewController: vc)
            //make app fullscreen as default
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: false)
        }
    }
    
    private func setupTableView(){
        tableVIew.delegate = self
        tableVIew.dataSource = self
    }
    
    private func fetchConvo(){
        tableVIew.isHidden = false
    }
}

extension ConvoViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: ConvoTableViewCell.identifier, for: indexPath) as! ConvoTableViewCell
        cell.configure(with: model)
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConvo(model)
       
    }
    func openConvo(_ model: Conversation){
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingstyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath){
        if editingstyle == .delete {
            let conversationsId = conversations[indexPath.row].id
            tableView.beginUpdates()
            DatabaseManager.shared.deleteConvo(conversationId:conversationsId , completion: { [weak self]success in
                if success {
                    self?.conversations.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .left)
                }
            })
            
            tableView.endUpdates()
        }
    }
}
