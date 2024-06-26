//
//  HomeViewModel.swift
//  TrainingTimer_ios
//
//  Created by 住田雅隆 on 2023/12/24.
//

import Combine
import SwiftUI
import AVFoundation

class HomeViewModel: ObservableObject {
    @Published private(set) var firstProgressValue: CGFloat = 0.0
    @Published private(set) var secondProgressValue: CGFloat = 0.0

    @Published private(set) var progressColor: Color = .trainingProgressBackgroundColor
    @Published private(set) var trainingPhase: TrainingPhase = .ready

    @Published private(set) var remainingTime: Int = 0

    @Published private(set) var remainingSets: Int = 0
    @Published private(set) var remainingRepetitions: Int = 0
    @Published private(set) var remainingRestBetweenSets: Int = 0
    @Published private(set) var readyTime: Int = 0

    @Published private(set) var firstProgressIsHidden = false
    @Published private(set) var secondProgressIsHidden = true
    @Published private(set) var navigationTitle = ""
    @Published private(set) var currentTitle: Text = Text(" ")
    @Published var showNotSetTrainingAlert: Bool = false
    @AppStorage("firstInstall") var initialInstall = false
    let model = TrainingModel.shared
    let effectSound = SoundModel()

    private var currentActivityPhase: TrainingActivityStage = .preparing
    private var timer: Timer?
    private var sets: Int = 0
    private var repetitions: Int = 0
    private var prepareTime: Int = 0
    private var trainingTime: Int = 0
    private var restTime: Int = 0
    private var restBetweenSets: Int = 0
    private var remainingPrepareTime: Int = 0
    private var remainingTrainingTime: Int = 0
    private var remainingRestTime: Int = 0
    private var cancellables: Set<AnyCancellable> = []
    private(set) var isSetTraining: Bool = false

    init() {
        $trainingPhase
            .sink { [weak self] state in
                guard let self = self else { return }
                self.updateTimer(for: state)
            }
            .store(in: &cancellables)

        model.onTrainingMenusChanged = { [weak self] in
            guard let self = self else { return }
            self.updateForSelectedTrainingMenu()
        }
        // アプリ初回インストール時、サンプルトレーニングメニューを使用
        if !initialInstall {
            let initialTrainingMenu = TrainingMenu(name: String(localized: "トレーニング"), trainingTime: 20, restDuration: 2, repetitions: 2, sets: 2, restBetweenSets: 3, readyTime: 3, createdAt: Date(), index: 0, isSelected: true)
            model.appendTrainingMenu(initialTrainingMenu)
            setTrainingMenu(selectedMenu: initialTrainingMenu)
            initialInstall = true
            isSetTraining = true
        } else {
            if let selectedMenu = model.trainingMenus.first(where: { $0.isSelected }) {
                setTrainingMenu(selectedMenu: selectedMenu)
                isSetTraining = true
            } else {
                isSetTraining = false
            }
        }
    }

    private func updateForSelectedTrainingMenu() {
        if let selectedMenu = model.trainingMenus.first(where: { $0.isSelected }) {
            setTrainingMenu(selectedMenu: selectedMenu)
            isSetTraining = true
        } else {
            resetToDefaultValues()
            isSetTraining = false
        }
    }

    private func setTrainingMenu(selectedMenu: TrainingMenu) {
        remainingTime = selectedMenu.trainingTime
        sets = selectedMenu.sets
        repetitions = selectedMenu.repetitions
        prepareTime = selectedMenu.prepareTime
        trainingTime = selectedMenu.trainingTime
        restTime = selectedMenu.restTime
        restBetweenSets = selectedMenu.restBetweenSets

        remainingPrepareTime = selectedMenu.prepareTime
        remainingTrainingTime = selectedMenu.trainingTime
        remainingRestTime = selectedMenu.restTime
        remainingSets = selectedMenu.sets
        remainingRepetitions = selectedMenu.repetitions
        remainingRestBetweenSets = selectedMenu.restBetweenSets
        navigationTitle = selectedMenu.name
    }

    private func resetToDefaultValues() {
        remainingTime = 0
        sets = 0
        repetitions = 0
        prepareTime = 0
        trainingTime = 0
        restTime = 0
        restBetweenSets = 0

        remainingPrepareTime = 0
        remainingTrainingTime = 0
        remainingRestTime = 0
        remainingSets = 0
        remainingRepetitions = 0
        remainingRestBetweenSets = 0
        navigationTitle = ""
        currentTitle = Text(" ")
    }

    private func updateTimer(for state: TrainingPhase) {
        switch state {
        case .running:
            startTimer()
            // スリープを禁止する
            UIApplication.shared.isIdleTimerDisabled = true
        case .pause:
            pauseTimer()
        case .ready:
            stopTimer()
            // スリープを解除する
            UIApplication.shared.isIdleTimerDisabled = false
        case .resume:
            resumeTimer()
        }
    }

    func changeTrainingState(to newState: TrainingPhase) {
        trainingPhase = newState
    }

    private func startTimer() {
        currentActivityPhase = .preparing
        currentTitle = currentActivityPhase.title
        remainingTime = remainingPrepareTime
        progressColor = .prepareProgressBackgroundColor
        setupTimer()
    }

    private func updateTimerProgress() {
        switch currentActivityPhase {
        case .preparing:

            remainingPrepareTime -= 1
            remainingTime = remainingPrepareTime

            if remainingPrepareTime <= 0 {
                effectSound.countZeroSound()
                beginTrainingPeriod()
            }
            updateProgress(remainingPrepareTime, prepareTime)

        case .training:
            remainingTrainingTime -= 1
            remainingTime = remainingTrainingTime
            if remainingTrainingTime <= 0 {
                effectSound.countZeroSound()
                beginRestPeriod()
            }
            if remainingTrainingTime <= 2 && remainingTrainingTime > 0 {
                effectSound.countDown()
            }
            updateProgress(remainingTrainingTime, trainingTime)
        case .resting:
            remainingRestTime -= 1
            remainingTime = remainingRestTime
            if remainingRestTime <= 2 && remainingRestTime > 0 {
                effectSound.countDown()
            }
            if remainingRestTime <= 0 {
                effectSound.countZeroSound()
                beginNextSetOrRepetition()
            }
            updateProgress(remainingRestTime, restTime)
        case .restBetweenSets:
            remainingRestBetweenSets -= 1
            remainingTime = remainingRestBetweenSets
            if remainingRestBetweenSets <= 2 && remainingRestBetweenSets > 0 {
                effectSound.countDown()
            }
            if remainingRestBetweenSets <= 0 {
                effectSound.countZeroSound()
                beginTrainingPeriod()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    self.remainingRestBetweenSets = restBetweenSets
                }
            }
            updateProgress(remainingRestBetweenSets, restBetweenSets)
        }
    }

    private func beginTrainingPeriod() {
        remainingTime = remainingTrainingTime
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.currentActivityPhase = .training
            self.remainingRestTime = restTime
            self.progressColor = .trainingProgressBackgroundColor
            self.resetUIForNewPhase()
        }
    }

    private func beginRestPeriod() {
        if remainingSets == 1 && remainingRepetitions == 1 {
            remainingTime = trainingTime
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                trainingPhase = .ready
            }
            return
        }
        remainingTime = remainingRestTime
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.currentActivityPhase = .resting
            self.remainingTrainingTime = trainingTime
            self.progressColor = .restProgressBackgroundColor
            self.resetUIForNewPhase()
        }
    }

    private func beginNextSetOrRepetition() {
        if remainingRepetitions > 1 {
            self.currentActivityPhase = .training
            remainingTime = remainingTrainingTime
        } else if remainingSets > 1 {
            currentActivityPhase = .restBetweenSets
            remainingTime = remainingRestBetweenSets
        }

        if currentActivityPhase == .training {

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.remainingRepetitions -= 1
                self.remainingRestTime = restTime
                self.progressColor = .trainingProgressBackgroundColor
                self.resetUIForNewPhase()
            }
        } else if currentActivityPhase == .restBetweenSets {

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.remainingSets -= 1
                self.remainingRepetitions = repetitions
                self.remainingRestTime = restTime
                self.progressColor = .restBetweenSetsProgressBackgroundColor
                self.resetUIForNewPhase()
            }
        }
    }

    private func resetUIForNewPhase() {
        currentTitle = currentActivityPhase.title
        firstProgressIsHidden = secondProgressIsHidden ? true : false
        secondProgressIsHidden = !firstProgressIsHidden
        if firstProgressValue != 0.0 {
            firstProgressValue = 0.0
        }
        if secondProgressValue != 0.0 {
            secondProgressValue = 0.0
        }
    }

    private func updateProgress(_ remainingTime: Int, _ originalTime: Int) {
        let newProgressValue = 1.0 - CGFloat(remainingTime) / CGFloat(originalTime)
        firstProgressIsHidden ? (secondProgressValue = newProgressValue) : (firstProgressValue = newProgressValue)
    }

    private func resumeTimer() {
        setupTimer()
    }

    private func pauseTimer() {
        timer?.invalidate()
    }

    private func stopTimer() {
        timer?.invalidate()
        resetStatus()
    }

    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateTimerProgress()
            self.effectSound.click()
        }
    }

    private func resetStatus() {
        firstProgressValue = 0.0
        secondProgressValue = 0.0
        firstProgressIsHidden = secondProgressIsHidden ? true : false
        secondProgressIsHidden = !firstProgressIsHidden
        progressColor = .trainingProgressBackgroundColor
        remainingPrepareTime = prepareTime
        remainingTime = trainingTime
        remainingTrainingTime = trainingTime
        remainingRestTime = restTime
        remainingSets = sets
        remainingRepetitions = repetitions
        remainingRestBetweenSets = restBetweenSets
        currentActivityPhase = .preparing
        currentTitle = Text(" ")
    }
}
