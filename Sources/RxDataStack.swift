//
//  RxDataStack.swift
//  RxCoreStore
//
//  Copyright © 2017 John Rommel Estropia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import CoreStore
import RxCocoa
import RxSwift


// MARK: - DataStack

extension DataStack: ReactiveCompatible {
    
    // MARK: ReactiveCompatible
    
    public typealias CompatibleType = DataStack
}


// MARK: - Reactive

extension Reactive where Base == DataStack {
    
    // MARK: - StorageProgress
    
    public struct StorageProgress<T: StorageInterface> {
        
        public let storage: T
        public let progressObject: Progress?
        public let completed: Bool
        
        public var progress: Double {
            
            return self.completed
                ? 1
                : (self.progressObject?.fractionCompleted ?? 0.0)
        }
        
        
        // MARK: Internal
        
        internal init(storage: T, progress: Progress?, completed: Bool = false) {
            
            self.storage = storage
            self.progressObject = progress
            self.completed = completed
        }
    }
    
    
    // MARK: -
    
    public func addStorage<T: StorageInterface>(_ storage: T) -> Observable<T> {
        
        return Observable.create(
            { (observable) -> Disposable in
                
                self.base.addStorage(
                    storage,
                    completion: { (result) in
                        
                        switch result {
                            
                        case .success(let storage):
                            observable.onNext(storage)
                            observable.onCompleted()
                            
                        case .failure(let error):
                            observable.onError(error)
                        }
                    }
                )
                return Disposables.create()
            }
        )
    }
    
    public func addStorage<T: LocalStorage>(_ storage: T) -> Observable<StorageProgress<T>> {
        
        return Observable<StorageProgress<T>>.create(
            { (observable) in
                
                var progress: Progress?
                progress = self.base.addStorage(
                    storage,
                    completion: { (result) in
                        
                        switch result {
                            
                        case .success(let storage):
                            observable.onNext(StorageProgress(storage: storage, progress: progress, completed: true))
                            observable.onCompleted()
                            
                        case .failure(let error):
                            observable.onError(error)
                        }
                }
                )
                if let progress = progress {
                    
                    let disposable = progress.rx
                        .observeWeakly(Double.self, #keyPath(Progress.fractionCompleted))
                        .subscribe(
                            onNext: { _ in
                                
                                observable.onNext(StorageProgress(storage: storage, progress: progress))
                        }
                    )
                    return Disposables.create([disposable])
                }
                else {
                    
                    return Disposables.create()
                }
            }
        )
    }
    
    public func importObject<T: DynamicObject & ImportableObject>(_ into: Into<T>, source: T.ImportSource) -> Observable<T?> {
        
        return Observable<T?>.create(
            { (observable) -> Disposable in
                
                self.base.perform(
                    asynchronous: { (transaction) -> T? in
                        
                        return try transaction.importObject(
                            into,
                            source: source
                        )
                    },
                    success: { (object) in
                        
                        observable.onNext(object.flatMap(CoreStore.fetchExisting))
                        observable.onCompleted()
                    },
                    failure: { (error) in
                        
                        observable.onError(error)
                    }
                )
                return Disposables.create()
            }
        )
    }
    
    public func importObject<T: DynamicObject & ImportableObject>(_ object: T, source: T.ImportSource) -> Observable<T?> {
        
        return Observable<T?>.create(
            { (observable) -> Disposable in
                
                self.base.perform(
                    asynchronous: { (transaction) -> T? in
                        
                        guard let object = transaction.edit(object) else {
                            
                            try transaction.cancel()
                        }
                        try transaction.importObject(
                            object,
                            source: source
                        )
                        return object
                    },
                    success: { (object) in
                        
                        observable.onNext(object.flatMap(CoreStore.fetchExisting))
                        observable.onCompleted()
                    },
                    failure: { (error) in
                        
                        observable.onError(error)
                    }
                )
                return Disposables.create()
            }
        )
    }
    
    public func importUniqueObject<T: DynamicObject & ImportableUniqueObject>(_ into: Into<T>, source: T.ImportSource) -> Observable<T?> {
        
        return Observable<T?>.create(
            { (observable) -> Disposable in
                
                self.base.perform(
                    asynchronous: { (transaction) -> T? in
                        
                        return try transaction.importUniqueObject(
                            into,
                            source: source
                        )
                    },
                    success: { (object) in
                        
                        observable.onNext(object.flatMap(CoreStore.fetchExisting))
                        observable.onCompleted()
                    },
                    failure: { (error) in
                        
                        observable.onError(error)
                    }
                )
                return Disposables.create()
            }
        )
    }
    
    public func importUniqueObjects<T: DynamicObject & ImportableUniqueObject, S: Sequence>(
        _ into: Into<T>,
        sourceArray: S,
        preProcess: @escaping (_ mapping: [T.UniqueIDType: T.ImportSource]) throws -> [T.UniqueIDType: T.ImportSource] = { $0 }) -> Observable<[T]> where S.Iterator.Element == T.ImportSource {
        
        return Observable<[T]>.create(
            { (observable) -> Disposable in
                
                self.base.perform(
                    asynchronous: { (transaction) -> [T] in
                        
                        return try transaction.importUniqueObjects(
                            into,
                            sourceArray: sourceArray,
                            preProcess: preProcess
                        )
                    },
                    success: { (objects) in
                        
                        observable.onNext(CoreStore.fetchExisting(objects))
                        observable.onCompleted()
                    },
                    failure: { (error) in
                        
                        observable.onError(error)
                    }
                )
                return Disposables.create()
            }
        )
    }
    
    public func perform<T>(asynchronous: @escaping (AsynchronousDataTransaction) throws -> T) -> Observable<T> {
        
        return Observable<T>.create(
            { (observable) -> Disposable in
                
                self.base.perform(
                    asynchronous: asynchronous,
                    success: { (output) in
                        
                        observable.onNext(output)
                        observable.onCompleted()
                    },
                    failure: { (error) in
                    
                        observable.onError(error)
                    }
                )
                return Disposables.create()
            }
        )
    }
}


extension ObservableType {
    
    public func filterCompleted<T: LocalStorage>() -> Observable<E> where E == Reactive<DataStack>.StorageProgress<T> {
        
        return self.filter({ $0.completed })
    }
    
    public func filterProgress<T: LocalStorage>() -> Observable<Double> where E == Reactive<DataStack>.StorageProgress<T> {
        
        return self
            .filter({ !$0.completed })
            .map({ $0.progress })
    }
}