//
//  JobsView.swift
//  Bottle
//
//  Created by Cobalt Velvet on 2024/8/10.
//

import SwiftUI

struct JobsView: View {
    @Environment(\.appModel) var appModel

    @State private var state: JobsState?

    var body: some View {
        VStack {
            ViewThatFits {
                HStack(spacing: 15) { buttons }
                VStack(spacing: 5) { buttons }
            }

            stateView
        }
        .padding()
        .frame(minHeight: 500)
        .task {
            repeat {
                await fetchJobs()
                try? await Task.sleep(for: .seconds(1))
            } while !Task.isCancelled
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            Task { await updateFeeds() }
        } label: {
            Label("Update Feeds", systemImage: "doc.text.image")
        }
        Button {
            Task { await downloadImages() }
        } label: {
            Label("Download Images", systemImage: "photo.on.rectangle.angled")
        }
        Button {
            Task { await fetchJobs() }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise.circle")
        }
    }

    @ViewBuilder
    private var stateView: some View {
        if let state = state {
            List {
                Section("Feed Update") {
                    ForEach(state.feedUpdateJobs) { job in
                        feedUpdateState(job)
                    }
                }
                Section("Image Download") {
                    imageDownloadState(state.imageDownloadJob)
                }
                Section("Panda Gallery Download") {
                    ForEach(state.pandaDownloadJobs) { job in
                        pandaDownloadState(job)
                    }
                }
            }
        } else {
            Spacer()
        }
    }

    @ViewBuilder
    private func feedUpdateState(_ job: JobsState.FeedUpdate) -> some View {
        let feedName = appModel.feeds.first { $0.id == job.id }?.displayName
        let name = "\(job.community.capitalized) \"\(feedName ?? String(job.feedId))\""
        switch job.state {
        case .ready:
            stateLabel(job.state) {
                Text(name + ": Ready")
            }
        case .running:
            ProgressView {
                stateLabel(job.state) {
                    Text(name + ": Updating")
                    Text("\(job.fetched) posts").foregroundStyle(.secondary)
                }
            }
            .progressViewStyle(.linear)
            .tint(.blue)
        case .success:
            stateLabel(job.state) {
                Text(name + ": Done")
                Text("\(job.fetched) posts").foregroundStyle(.secondary)
            }
        case .failed:
            stateLabel(job.state) {
                Text(name + ": Failed")
                if let error = job.error {
                    Text(error)
                        .foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func imageDownloadState(_ job: JobsState.ImageDownload) -> some View {
        switch job.state {
        case .ready:
            stateLabel(job.state) {
                Text("Ready")
            }
        case .running:
            ProgressView(value: Float(job.success), total: Float(job.total)) {
                stateLabel(job.state) {
                    Text("Downloading")
                    if job.failure > 0 {
                        Text("\(job.failure) failed").foregroundStyle(.secondary)
                    }
                }
            }
            .progressViewStyle(.linear)
            .tint(.blue)
        case .success:
            stateLabel(job.state) {
                Text("Done")
                Text("\(job.total) images").foregroundStyle(.secondary)
            }
        case .failed:
            stateLabel(job.state) {
                Text("Failed")
                if let error = job.error {
                    Text(error)
                        .foregroundStyle(.secondary).textSelection(.enabled)
                }
                if let failures = job.failures {
                    DisclosureGroup("Failures") {
                        ForEach(failures, id: \.url) { failure in
                            Text("\(failure.url): \(failure.error)")
                                .foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pandaDownloadState(_ job: JobsState.PandaDownload) -> some View {
        switch job.state {
        case .ready:
            stateLabel(job.state) {
                Text(job.title + ": Ready")
            }
        case .running where !job.metadataFetched:
            ProgressView(value: Float(job.successPages), total: Float(job.totalPages)) {
                stateLabel(job.state) {
                    Text(job.title + ": Fetching metadata")
                }
            }
            .progressViewStyle(.linear)
            .tint(.blue)
        case .running:
            ProgressView(value: Float(job.successImages), total: Float(job.totalImages)) {
                stateLabel(job.state) {
                    Text(job.title + ": Downloading images")
                    if job.failureImages > 0 {
                        Text("\(job.failureImages) failed").foregroundStyle(.secondary)
                    }
                }
            }
            .progressViewStyle(.linear)
            .tint(.blue)
        case .success:
            stateLabel(job.state) {
                Text(job.title + ": Done")
                Text("\(job.totalImages) images").foregroundStyle(.secondary)
            }
        case .failed:
            stateLabel(job.state) {
                Text(job.title + ": Failed")
                if let error = job.error {
                    Text(error)
                        .foregroundStyle(.secondary).textSelection(.enabled)
                }
                if let failures = job.failures {
                    DisclosureGroup("Failures") {
                        ForEach(failures) { failure in
                            Text("\(failure.gid)-\(failure.index): \(failure.error)")
                                .foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private func stateLabel<V: View>(_ state: JobsState.State, @ViewBuilder _ content: () -> V) -> some View {
        switch state {
        case .ready:
            Label {
                VStack(alignment: .leading) { content() }
            } icon: {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.gray)
            }
        case .running:
            Label {
                VStack(alignment: .leading) { content() }
            } icon: {
                Image(systemName: "square.and.arrow.down").foregroundStyle(.blue)
            }
        case .success:
            Label {
                VStack(alignment: .leading) { content() }
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        case .failed:
            Label {
                VStack(alignment: .leading) { content() }
            } icon: {
                Image(systemName: "xmark.circle").foregroundStyle(.red)
            }
        }
    }

    private func updateFeeds() async {
        do {
            if let names = appModel.metadata?.communities.map(\.name) {
                try await Client.updateFeeds(communityNames: names)
            }
        } catch {
            print(error)
        }
    }

    private func downloadImages() async {
        do {
            try await Client.downloadImages()
        } catch {
            print(error)
        }
    }

    private func fetchJobs() async {
        do {
            state = try await Client.fetchJobs().sorted()
        } catch {
            print(error)
        }
    }
}

#Preview {
    JobsView()
}
