//
//  TrainingMenuCreationViewModel.swift
//  TrainingTimer
//
//  Created by 住田雅隆 on 2024/01/10.
//

import SwiftUI
import SwiftData

@Observable
class TrainingModel {
    @ObservationIgnored
    private let databaseManager: DatabaseManager

    static let shared = TrainingModel()
    var trainingMenus: [TrainingMenu] = []
    var onTrainingMenusChanged: (() -> Void)?

    init(databaseManager: DatabaseManager = DatabaseManager.shared) {
        self.databaseManager = databaseManager
        trainingMenus = databaseManager.fetchTrainingMenu().sorted(by: { $0.index < $1.index })
    }

    func appendTrainingMenu(_ trainingMenu: TrainingMenu) {
        databaseManager.addTrainingMenu(trainingMenu: trainingMenu)
        trainingMenus.append(trainingMenu)
    }

    func removeItem(index: Int) {
        databaseManager.removeTrainingMenu(trainingMenus[index])

        trainingMenus.remove(at: index)
        // 削除したアイテムのindexより大きい全てのアイテムのindexを更新
        for i in index..<trainingMenus.count {
            trainingMenus[i].index -= 1
            databaseManager.updateTrainingMenu(trainingMenus[i])
        }
        onTrainingMenusChanged?()
    }

    func updateTrainingMenu(_ trainingMenu: TrainingMenu) {
        databaseManager.updateTrainingMenu(trainingMenu)
        onTrainingMenusChanged?()
    }
}
