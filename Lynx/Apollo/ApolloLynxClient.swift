//
//  Apollo.swift
//  Lynx
//
//  Created by Matthew Ernst on 4/29/23.
//

import Foundation
import Apollo
import OSLog

typealias Logbook = ApolloGeneratedGraphQL.GetLogsQuery.Data.SelfLookup.Logbook
typealias Logbooks = [Logbook]

typealias MeasurementSystem = ApolloGeneratedGraphQL.MeasurementSystem

typealias OAuthLoginIds = [ApolloGeneratedGraphQL.GetProfileInformationQuery.Data.SelfLookup.OauthLoginId]
typealias OAuthType = ApolloGeneratedGraphQL.OAuthType
protocol Leaderboard {
    var firstName: String { get }
    var lastName: String { get }
    var profilePictureUrl: String? { get }
    var logbooks: LeaderLogbooks { get }
}
extension ApolloGeneratedGraphQL.GetAllLeaderboardsQuery.Data.DistanceLeader: Leaderboard {
    var logbooks: LeaderLogbooks {
        .distanceLogbook(self.logbook)
    }
}
extension ApolloGeneratedGraphQL.GetAllLeaderboardsQuery.Data.RunCountLeader: Leaderboard {
    var logbooks: LeaderLogbooks {
        .runCountLogbook(self.logbook)
    }
}
extension ApolloGeneratedGraphQL.GetAllLeaderboardsQuery.Data.TopSpeedLeader: Leaderboard {
    var logbooks: LeaderLogbooks {
        .topSpeedLogbook(self.logbook)
    }
}
extension ApolloGeneratedGraphQL.GetAllLeaderboardsQuery.Data.VerticalDistanceLeader: Leaderboard {
    var logbooks: LeaderLogbooks {
        .verticalDistanceLogbook(self.logbook)
    }
}
extension ApolloGeneratedGraphQL.GetSelectedLeaderboardQuery.Data.Leaderboard: Leaderboard {
    var logbooks: LeaderLogbooks {
        .selectedLeader(self.logbook)
    }
}
typealias LeaderboardLeaders = [Leaderboard]

typealias LeaderboardSort = ApolloGeneratedGraphQL.LeaderboardSort

enum LeaderLogbooks {
    case distanceLogbook([ApolloGeneratedGraphQL.GetAllLeaderboardsQuery.Data.DistanceLeader.Logbook])
    case runCountLogbook([ApolloGeneratedGraphQL.GetAllLeaderboardsQuery.Data.RunCountLeader.Logbook])
    case topSpeedLogbook([ApolloGeneratedGraphQL.GetAllLeaderboardsQuery.Data.TopSpeedLeader.Logbook])
    case verticalDistanceLogbook([ApolloGeneratedGraphQL.GetAllLeaderboardsQuery.Data.VerticalDistanceLeader.Logbook])
    case selectedLeader([ApolloGeneratedGraphQL.GetSelectedLeaderboardQuery.Data.Leaderboard.Logbook])
}



class ApolloLynxClient {
    private static let graphQLEndpoint = Constants.graphQLEndpoint
    
    private static let apolloClient: ApolloClient = {
        // The cache is necessary to set up the store, which we're going
        // to hand to the provider
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)
        
        let client = URLSessionClient()
        let provider = NetworkInterceptorProvider(store: store, client: client)
        let url = URL(string: graphQLEndpoint)!
        
        let requestChainTransport = RequestChainNetworkTransport(
            interceptorProvider: provider,
            endpointURL: url
        )
        
        // Remember to give the store you already created to the client so it
        // doesn't create one on its own
        return ApolloClient(networkTransport: requestChainTransport, store: store)
    }()
    
    public static func clearCache() {
        apolloClient.store.clearCache()
    }
    
    public static func getProfileInformation(completion: @escaping (Result<ProfileAttributes, Error>) -> Void) {
        
        apolloClient.fetch(query: ApolloGeneratedGraphQL.GetProfileInformationQuery()) { result in
            switch result {
            case .success(let graphQLResult):
                guard let selfLookup = graphQLResult.data?.selfLookup else {
                    Logger.apollo.error("selfLookup did not have any data.")
                    completion(.failure(UserError.noProfileAttributesReturned))
                    return
                }
                
                // TODO: First okay?
                let oauthIds = selfLookup.oauthLoginIds

                guard let type = oauthIds.first?.type else {
                    Logger.apollo.error("oauthLoginIds failed to unwrap type.")
                    return
                }
                
                guard let id = oauthIds.first?.id else {
                    Logger.apollo.error("oauthLoginIds failed to unwrap id.")
                    return
                }
                
                guard let oauthToken = UserDefaults.standard.string(forKey: UserDefaultsKeys.oauthToken) else {
                    Logger.apollo.error("oauthToken not found in UserDefaults.")
                    return
                }
                
                
                let profileAttributes = ProfileAttributes(type: type.rawValue,
                                                          oauthToken: oauthToken,
                                                          id: id,
                                                          email: selfLookup.email,
                                                          firstName: selfLookup.firstName,
                                                          lastName: selfLookup.lastName,
                                                          profilePictureURL: selfLookup.profilePictureUrl)
                Logger.apollo.debug("ProfileAttributes being returned:\n \(profileAttributes.debugDescription)")
                completion(.success(profileAttributes))
            case .failure(let error):
                Logger.apollo.error("\(error)")
                completion(.failure(error))
            }
        }
    }
    
    public static func getOAuthOAuthTypes(completion: @escaping (Result<[String], Error>) -> Void) {
        
        apolloClient.fetch(query: ApolloGeneratedGraphQL.GetOAuthLoginsQuery()) { result in
            switch result {
            case .success(let graphQLResult):
                guard let oauthLogins = graphQLResult.data?.selfLookup?.oauthLoginIds else {
                    Logger.apollo.error("OauthLogins failed in getOAuthLogins")
                    return
                }
                
                completion(.success(oauthLogins.map({ $0.type.rawValue })))
                
            case .failure(let error):
                Logger.apollo.error("Failed to get oauth login ids")
                completion(.failure(error))
            }
        }
    }
    
    public static func loginOrCreateUser(type: String, id: String, token: String, email: String?, firstName: String?, lastName: String?, profilePictureUrl: String?, completion: @escaping (Result<Bool, Error>) -> Void) {
        
        Logger.apollo.debug("Login in with following: type               -> \(type)")
        Logger.apollo.debug("                         id                 -> \(id)")
        Logger.apollo.debug("                         token              -> \(token)")
        Logger.apollo.debug("                         email              -> \(email ?? "nil")")
        Logger.apollo.debug("                         firstName          -> \(firstName ?? "nil")")
        Logger.apollo.debug("                         lastName           -> \(lastName ?? "nil")")
        Logger.apollo.debug("                         profilePictureUrl  -> \(profilePictureUrl ?? "nil")")
        
        
        var userData: [ApolloGeneratedGraphQL.UserDataPair] = []
        var userDataNullable = GraphQLNullable<[ApolloGeneratedGraphQL.UserDataPair]>(nilLiteral: ())
        
        if let firstName = firstName, let lastName = lastName, let profilePictureUrl = profilePictureUrl {
            userData.append(ApolloGeneratedGraphQL.UserDataPair(key: "firstName", value: firstName))
            userData.append(ApolloGeneratedGraphQL.UserDataPair(key: "lastName", value: lastName))
            userData.append(ApolloGeneratedGraphQL.UserDataPair(key: "profilePictureUrl", value: profilePictureUrl))
            userDataNullable = GraphQLNullable<[ApolloGeneratedGraphQL.UserDataPair]>(arrayLiteral: userData[0], userData[1], userData[2])
        }
        
        let type = GraphQLEnum<ApolloGeneratedGraphQL.OAuthType>(rawValue: type)
        let tokenWrappedInGraphQL = GraphQLNullable<ApolloGeneratedGraphQL.ID>(stringLiteral: token)
        let oauthLoginId = ApolloGeneratedGraphQL.OAuthTypeCorrelationInput(type: type, id: id, token: tokenWrappedInGraphQL)
        
        
        let emailNullable: GraphQLNullable<String>
        if email == nil {
            emailNullable = GraphQLNullable<String>(nilLiteral: ())
        } else {
            emailNullable = GraphQLNullable<String>(stringLiteral: email!)
        }
        
        apolloClient.perform(mutation: ApolloGeneratedGraphQL.LoginOrCreateUserMutation(oauthLoginId: oauthLoginId,
                                                                                        email: emailNullable,
                                                                                        userData: userDataNullable)) { result in
            switch result {
            case .success(let graphQLResult):
                guard let data = graphQLResult.data?.createUserOrSignIn else {
                    let error = UserError.noAuthorizationTokenReturned
                    completion(.failure(error))
                    return
                }
                
                let authorizationToken = data.token
                
                guard let expiryInMilliseconds = Double(data.expiryDate) else {
                    Logger.apollo.error("Could not convert expiryDate to Double.")
                    return
                }
                
                let expirationDate = Date(timeIntervalSince1970: expiryInMilliseconds / 1000)
                
                UserManager.shared.token = ExpirableAuthorizationToken(authorizationToken: authorizationToken, expirationDate: expirationDate, oauthToken: token)
                
                completion(.success((data.validatedInvite)))
                
            case .failure(let error):
                Logger.apollo.error("LoginOrCreateUser mutation failed with Error: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    public static func createInviteKey(completion: @escaping ((Result<String, Error>) -> Void)) {
        enum CreateInviteKeyError: Error {
            case failedToUnwrapData
        }
        apolloClient.perform(mutation: ApolloGeneratedGraphQL.CreateInviteKeyMutation()) { result in
            switch result {
            case .success(let graphQLResult):
                guard let inviteKey = graphQLResult.data?.createInviteKey else {
                    Logger.apollo.error("Error: Failed to unwrap data for invite key.")
                    completion(.failure(CreateInviteKeyError.failedToUnwrapData))
                    return
                }
                
                completion(.success(inviteKey))
                
            case .failure(let error):
                Logger.apollo.error("Error: Failed to create invite key with error \(error)")
                completion(.failure(error))
            }
        }
    }
    
    public static func submitInviteKey(with invitationKey: String, completion: @escaping ((Result<Void, Error>) -> Void)) {
        enum InviteKeyError: Error {
            case failedValidateInvite
        }
        apolloClient.perform(mutation: ApolloGeneratedGraphQL.SubmitInviteKeyMutation(inviteKey: invitationKey)) { result in
            switch result {
            case .success(let graphQLResult):
                if let validatedInvite = graphQLResult.data?.resolveInviteKey.validatedInvite, validatedInvite {
                    completion(.success(()))
                } else {
                    completion(.failure(InviteKeyError.failedValidateInvite))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public static func editUser(profileChanges: [String: Any], completion: @escaping ((Result<String, Error>) -> Void)) {
        
        enum EditUserErrors: Error {
            case editUserNil
            case profilePictureURLMissing
        }
        
        var userData: [ApolloGeneratedGraphQL.UserDataPair] = []
        for (key, value) in profileChanges {
            let stringValue = String(describing: value)
            userData.append(ApolloGeneratedGraphQL.UserDataPair(key: key, value: stringValue))
        }
        
        apolloClient.perform(mutation: ApolloGeneratedGraphQL.EditUserMutation(userData: userData)) { result in
            switch result {
            case .success(let graphQLResult):
                guard let editUser = graphQLResult.data?.editUser else {
                    Logger.apollo.error("editUser unwrapped to nil.")
                    completion(.failure(EditUserErrors.editUserNil))
                    return
                }
                
                guard let newProfilePictureUrl = editUser.profilePictureUrl else {
                    Logger.apollo.error("Not able to find profilePictureUrl in editUser object.")
                    completion(.failure(EditUserErrors.profilePictureURLMissing))
                    return
                }
                
                Logger.apollo.info("Successfully got editUser.profilePictureUrl.")
                print(newProfilePictureUrl)
                completion(.success(newProfilePictureUrl))
                
            case .failure(let error):
                Logger.apollo.error("Failed to Edit User Information. \(error)")
                completion(.failure(error))
            }
        }
    }
    
    public static func createUserProfilePictureUploadUrl(completion: @escaping ((Result<String, Error>) -> Void)) {
        
        apolloClient.perform(mutation: ApolloGeneratedGraphQL.CreateUserProfilePictureUploadUrlMutation()) { result in
            switch result {
            case .success(let graphQLResult):
                guard let url = graphQLResult.data?.createUserProfilePictureUploadUrl else {
                    Logger.apollo.error("Unable to unwrap createUserProfilePictureUploadUrl")
                    return
                }
                Logger.apollo.info("Successfully retrieved createUserProfilePictureUrl.")
                Logger.apollo.debug("createUSerProfilePictureUrl: \(url)")
                completion(.success(url))
                
            case .failure(let error):
                Logger.apollo.error("Failed to retrieve createUserProfilePictureUrl.")
                completion(.failure(error))
            }
        }
    }
    
    public static func createUserRecordUploadUrl(filesToUpload: [String], completion: @escaping ((Result<[String], Error>) -> Void)) {
        
        enum RunRecordURLErrors: Error {
            case nilURLs
            case mismatchNumberOfURLs
        }
        
        apolloClient.perform(mutation: ApolloGeneratedGraphQL.CreateRunRecordUploadUrlMutation(requestedPaths: filesToUpload)) { result in
            switch result {
            case .success(let graphQLResult):
                guard let urls = graphQLResult.data?.createUserRecordUploadUrl else {
                    Logger.apollo.error("Unable to unwrap createUserRecordUploadUrl.")
                    return
                }
                
                if urls.contains(where: { $0 == nil }) {
                    Logger.apollo.error("One or more of the URL's returned contains nil.")
                    return completion(.failure(RunRecordURLErrors.nilURLs))
                }
                
                if filesToUpload.count != urls.count {
                    Logger.apollo.error("The number of URL's returned does not match the number of files requested for upload.")
                    return completion(.failure(RunRecordURLErrors.mismatchNumberOfURLs))
                }
                Logger.apollo.info("Successfully acquired urls for run record upload.")
                completion(.success(urls.compactMap { $0 })) // Unwrapping all internal url optionals
                
            case .failure(_):
                break
            }
        }
    }
    
    enum QueryLogbookErrors: Error {
        case logbookIsNil
        case queryFailed
    }
    
    public static func getUploadedLogs(completion: @escaping ((Result<Set<String>, Error>) -> Void)) {
        
        apolloClient.fetch(query: ApolloGeneratedGraphQL.GetUploadedLogsQuery()) { result in
            switch result {
            case .success(let graphQLResult):
                guard let logbook = graphQLResult.data?.selfLookup?.logbook else {
                    Logger.apollo.error("logbook could not be unwrapped.")
                    completion(.failure(QueryLogbookErrors.logbookIsNil))
                    return
                }
                
                let uploadedSlopeFiles = Set(logbook.map { $0.originalFileName.split(separator: "/").last.map(String.init) ?? "" })
                Logger.apollo.info("Successfully retrieved logs.")
                return completion(.success(uploadedSlopeFiles))
                
            case .failure(_):
                Logger.apollo.error("Error querying users logbook.")
                completion(.failure(QueryLogbookErrors.queryFailed))
            }
        }
    }
    
    public static func getLogs(measurementSystem: MeasurementSystem, completion: @escaping ((Result<Logbooks, Error>) -> Void)) {
        
        let system = GraphQLEnum<ApolloGeneratedGraphQL.MeasurementSystem>(rawValue: measurementSystem.rawValue)
        
        apolloClient.fetch(query: ApolloGeneratedGraphQL.GetLogsQuery(system: system)) { result in
            switch result {
            case .success(let graphQLResult):
                guard var logbook = graphQLResult.data?.selfLookup?.logbook else {
                    Logger.apollo.error("logbook could not be unwrapped.")
                    completion(.failure(QueryLogbookErrors.logbookIsNil))
                    return
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                
                logbook.sort { (a: Logbook, b: Logbook) in
                    let date1 = dateFormatter.date(from: a.startDate) ?? Date()
                    let date2 = dateFormatter.date(from: b.startDate) ?? Date()
                    
                    return date1 > date2
                }
                
                return completion(.success(logbook))
                
            case .failure(_):
                Logger.apollo.error("Error querying users logbook.")
                completion(.failure(QueryLogbookErrors.queryFailed))
            }
        }
    }
    
    public static func deleteAccount(token: String, type: ApolloGeneratedGraphQL.OAuthType, completion: @escaping ((Result<Void, Error>) -> Void)) {
        enum DeleteAccountErrors: Error {
            case UnwrapOfReturnedUserFailed
            case BackendCouldntDelete
        }
        
        let deleteUserOptions = ApolloGeneratedGraphQL.DeleteUserOptions(tokensToInvalidate: GraphQLNullable<[ApolloGeneratedGraphQL.InvalidateTokenOption]>(arrayLiteral: ApolloGeneratedGraphQL.InvalidateTokenOption(token: token, type: GraphQLEnum(type))))
        
        apolloClient.perform(mutation: ApolloGeneratedGraphQL.DeleteAccountMutation(options: deleteUserOptions)) { result in
            switch result {
            case .success(let graphQLResult):
                guard let _ = graphQLResult.data?.deleteUser.id else {
                    Logger.apollo.error("Couldn't unwrap delete user.")
                    completion(.failure(DeleteAccountErrors.UnwrapOfReturnedUserFailed))
                    return
                }
                
                Logger.apollo.info("Successfully deleted user.")
                completion(.success(()))
                
            case .failure(let error):
                Logger.apollo.error("Failed to delete user: \(error)")
                completion(.failure(DeleteAccountErrors.BackendCouldntDelete))
            }
        }
    }
    
    public static func mergeAccount(with account: ApolloGeneratedGraphQL.OAuthTypeCorrelationInput, completion: @escaping ((Result<Void, Error>) -> Void)) {
        enum MergeAccountErrors: Error {
            case UnwrapOfReturnedUserFailed
            case BackendCouldntMerge
        }
        apolloClient.perform(mutation: ApolloGeneratedGraphQL.CombineOAuthAccountsMutation(combineWith: account)) { result in
            
            switch result {
            case .success(let graphQLResult):
                guard let _ = graphQLResult.data?.combineOAuthAccounts.id else {
                    Logger.apollo.error("Couldn't unwrap merge account id.")
                    completion(.failure(MergeAccountErrors.UnwrapOfReturnedUserFailed))
                    return
                }
                
                completion(.success(()))
                
            case .failure(let error):
                Logger.apollo.error("Failed to merge accounts: \(error)")
                completion(.failure(MergeAccountErrors.BackendCouldntMerge))
            }
        }
    }
    
    public static func getAllLeaderboards(limit: Int?, inMeasurementSystem system: MeasurementSystem, completion: @escaping ((Result<[LeaderboardSort: [LeaderboardAttributes]], Error>) -> Void)) {
        enum GetAllLeadersErrors: Error {
            case unableToUnwrap
        }

        let nullableLimit: GraphQLNullable<Int> = (limit != nil) ? .init(integerLiteral: limit!) : .null
        let enumSystem = GraphQLEnum<MeasurementSystem>(rawValue: system.rawValue)
        apolloClient.fetch(query: ApolloGeneratedGraphQL.GetAllLeaderboardsQuery(limit: nullableLimit, measurementSystem: enumSystem)) { result in
            switch result {
            case .success(let graphQLResult):

                guard let data = graphQLResult.data else {
                    Logger.apollo.error("Error unwrapping All Leaders data")
                    completion(.failure(GetAllLeadersErrors.unableToUnwrap))
                    return
                }

                // Create a dispatch group to track ongoing profile picture downloads
                let downloadGroup = DispatchGroup()

                var leaderboardAttributes: [LeaderboardSort: [LeaderboardAttributes]] = [:]

                for sort in LeaderboardSort.allCases {
                    var leadersAttributes: [LeaderboardAttributes] = []

                    let leaders: [Leaderboard]

                    switch sort {
                    case .distance:
                        leaders = data.distanceLeaders
                    case .runCount:
                        leaders = data.runCountLeaders
                    case .topSpeed:
                        leaders = data.topSpeedLeaders
                    case .verticalDistance:
                        leaders = data.verticalDistanceLeaders
                    }

                    for leader in leaders {
                        downloadGroup.enter()
                        let attributes = LeaderboardAttributes(leader: leader, category: sort) {
                            downloadGroup.leave()
                        }
                        leadersAttributes.append(attributes)
                    }

                    leaderboardAttributes[sort] = leadersAttributes
                }

                // Wait for all profile picture downloads to finish before calling the completion block
                downloadGroup.notify(queue: .main) {
                    completion(.success(leaderboardAttributes))
                }

            case .failure(let error):
                Logger.apollo.error("Error Fetching All Leaders: \(error)")
                completion(.failure(error))
            }
        }
    }

    
    public static func getSelectedLeaderboard(_ leaderboard: LeaderboardSort, limit: Int?, inMeasurementSystem system: MeasurementSystem, completion: @escaping ((Result<[LeaderboardAttributes], Error>) -> Void)) {
        
        enum SelectedLeaderboardError: Error
        {
            case unwrapError
        }
        
        let nullableLimit: GraphQLNullable<Int> = (limit != nil) ? .init(integerLiteral: limit!) : .null
        let enumSystem = GraphQLEnum<MeasurementSystem>(rawValue: system.rawValue)
        let enumSort = GraphQLEnum<LeaderboardSort>(rawValue: leaderboard.rawValue)
        apolloClient.fetch(query: ApolloGeneratedGraphQL.GetSelectedLeaderboardQuery(limit: nullableLimit, measurementSystem: enumSystem, selectedLeaderboard: enumSort)) { result in
            
            switch result {
            case .success(let graphQLResult):
                guard let selectedLeaderboard = graphQLResult.data?.leaderboard else {
                    Logger.apollo.error("Failed to unwrap selected leaderboard.")
                    completion(.failure(SelectedLeaderboardError.unwrapError))
                    return
                }
                
                let dispatchGroup = DispatchGroup()
                var leaderData = [LeaderboardAttributes]()
                
                for leader in selectedLeaderboard {
                    dispatchGroup.enter()
                    leaderData.append(LeaderboardAttributes(leader: leader, category: leaderboard) {
                        dispatchGroup.leave()
                    })
                }
                
                
                dispatchGroup.notify(queue: .main) {
                    completion(.success(leaderData))
                }
                
            case .failure(let error):
                Logger.apollo.error("Error Fetching Selected Leaderbords: \(error)")
                completion(.failure(error))
            }
        }
    }
    
}


// MARK: - ProfileAttributes
struct ProfileAttributes: CustomDebugStringConvertible
{
    var type: String
    var oauthToken: String
    var id: String
    var email: String
    var firstName: String
    var lastName: String
    var profilePictureURL: String
    
    init(type: String, oauthToken: String, id: String, email: String, firstName: String, lastName: String, profilePictureURL: String? = "") {
        self.type = type
        self.oauthToken = oauthToken
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.profilePictureURL = profilePictureURL ?? ""
    }
    
    var debugDescription: String {
       """
       id: \(self.id)
       type: \(self.type)
       oauthToken: \(self.oauthToken)
       firstName: \(self.firstName)
       lastName: \(self.lastName)
       email: \(self.email)
       profilePictureURL: \(String(describing: self.profilePictureURL))
       """
    }
}
