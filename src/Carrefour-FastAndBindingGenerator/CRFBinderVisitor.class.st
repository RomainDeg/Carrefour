"
Binds FAST nodes to their corresponding FamixEntities

Visit the F-AST and create binding between variable accesses (`FASTJavaFieldAccess`, `FASTJavaAssignementExpression`, `FASTJavaIdentifier`, ...) or method invocations (`FASTJavaMethodInvocation`) and their Famix counter-part (`FamixTStructuralEntity`, `FamixTInvocation`, ...)
"
Class {
	#name : #CRFBinderVisitor,
	#superclass : #FASTJavaVisitor,
	#instVars : [
		'sourceFamixEntity'
	],
	#category : #'Carrefour-FastAndBindingGenerator'
}

{ #category : #api }
CRFBinderVisitor class >> bindFastModel: fastModel fromEntity: aFamixEntity [
	^ self new bindFastModel: fastModel fromEntity: aFamixEntity
]

{ #category : #api }
CRFBinderVisitor class >> bindFastModel: fastModel fromFamixMethodEntity: aFamixEntity [
	^ self new bindFastModel: fastModel fromFamixMethodEntity: aFamixEntity
]

{ #category : #api }
CRFBinderVisitor >> bindFastModel: fastModel fromEntity: aFamixMethodEntity [
	aFamixMethodEntity bindFastModel: fastModel usingBinder: self
]

{ #category : #api }
CRFBinderVisitor >> bindFastModel: fastModel fromFamixClassEntity: aFamixClassEntity [
	self
		execute: [ self sourceFamixEntity: aFamixClassEntity.
			(fastModel allWithSubTypesOfAny: {FASTJavaClassDeclaration. FASTJavaInterfaceDeclaration}) asOrderedCollection
				select: [ :classDeclaration | classDeclaration parentNode isNil ]
				thenDo: [ :classDeclaration | self accept: classDeclaration ].
			fastModel metamodel: CRFModel metamodel ]
		recordedAs: 'Bind ' , aFamixClassEntity mooseName printString
]

{ #category : #api }
CRFBinderVisitor >> bindFastModel: fastModel fromFamixMethodEntity: aFamixMethodEntity [
	self
		execute: [ self sourceFamixEntity: aFamixMethodEntity.
			fastModel allFASTJavaMethodEntity
				select: [ :methodEntity | methodEntity parentNode isNil ]
				thenDo: [ :methodEntity | self accept: methodEntity ].
			(fastModel allWithType: FASTJavaInitializer) do: [ :methodEntity | self accept: methodEntity ].
			fastModel metamodel: CRFModel metamodel ]
		recordedAs: 'Bind ' , aFamixMethodEntity mooseName printString
]

{ #category : #visitor }
CRFBinderVisitor >> compareSourceFamixEntityNameWithFastEntityName: aFASTJavaMethodName [

	| famixEntityName |
	famixEntityName := (sourceFamixEntity isConstructor and: [ 
		                    sourceFamixEntity parentType isClass and: [ 
			                    sourceFamixEntity parentType isAnonymousClass ] ])
		                   ifTrue: [ "this method is the constructor of an anonymous class, so the name needs to be parsed" 
			                   self sourceFamixEntityNameWithoutAnonymousPrefix ]
		                   ifFalse: [ "general case, no parsing to do" 
		                   sourceFamixEntity name ].

	^ aFASTJavaMethodName = famixEntityName
]

{ #category : #'private - action' }
CRFBinderVisitor >> determineAttributeWithName: aVariableName from: aFASTEntity [

	"I do a lookup for a variable in the famix code with the name = aVariableName 
	 I return the variable if found nil else
	
	It should have only one variable possible for one identifier (if the lookup is done correctly)"
	aVariableName ifNil: [ ^ nil ].
	((aFASTEntity atAnyScope: { 
			  FASTJavaInitializer.
			  FASTJavaMethodEntity }) reject: [ :fastElement | 
		 fastElement famixMethod isNil ])
		ifNotEmpty: [ :collectionOfMethods | 
			(collectionOfMethods anyOne famixMethod allAtScope: FamixTMethod) 
				do: [ :aFamixMethod | 
					(self
						 determineAttributeWithName: aVariableName
						 ofFamixMethod: aFamixMethod
						 for: aFASTEntity) ifNotNil: [ :found | ^ found ] ] ]
		ifEmpty: [ "We are in a FASTJavaClassDeclaration (sourceFamixEntity) and in a direct creation
			ifNone it is probably the name of a type... so we do not care
			"
			(self
				 determineAttributeWithName: aVariableName
				 fromFamixEntity:
					 (aFASTEntity atAnyScope: {FASTJavaInterfaceDeclaration . FASTJavaClassDeclaration}) anyOne
						 famixTypeDefinition) ifNotNil: [ :found | ^ found ].
			
			self sourceFamixEntity attributes
				detect: [ :attribute | attribute name = aVariableName ]
				ifFound: [ :attribute | ^ attribute ] ].
	^ nil
]

{ #category : #'private - action' }
CRFBinderVisitor >> determineAttributeWithName: aVariableName fromFamixEntity: aFamixEntity [

	((((aFamixEntity allAtAnyScope: { 
			    FamixTParameterizedType.
			    FamixTClass }) flatCollect: #withSuperclassHierarchy) select: [ 
		  :hierarchyElement | hierarchyElement isKindOf: FamixJavaClass ]) 
		 sorted: [ :classA :classB | 
			 classA superclassHierarchy size > classB superclassHierarchy size ]) 
		ifNotEmpty: [ :scopes | 
			scopes do: [ :scope | 
				scope attributes
					detect: [ :implicitVariable | 
					implicitVariable name = aVariableName ]
					ifFound: [ :found | ^ found ] ] ].
	^ nil
]

{ #category : #'private - action' }
CRFBinderVisitor >> determineAttributeWithName: aVariableName ofFamixMethod: aFamixMethod for: aFastEntity [

	aFamixMethod localVariables
		detect: [ :localVariable | localVariable name = aVariableName ]
		ifFound: [ :found | ^ found ].
	aFamixMethod parameters
		detect: [ :parameter | parameter name = aVariableName ]
		ifFound: [ :found | ^ found ].
	aFamixMethod implicitVariables
		detect: [ :implicitVariable | implicitVariable name = aVariableName ]
		ifFound: [ :found | ^ found ].
	(aFastEntity allAtScope: FASTJavaNewClassExpression) do: [ 
		:aFastJavaNewClassExpression | 
		aFastJavaNewClassExpression famixType attributes
			detect: [ :attribute | attribute name = aVariableName ]
			ifFound: [ :found | ^ found ] ].
	"(((aFamixMethod allAtAnyScope: { 
			   FamixTParameterizedType.
			   FamixTClass }) flatCollect: #withSuperclassHierarchy) select: [ 
		 :hierarchyElement | hierarchyElement isKindOf: FamixJavaClass ]) ifNotEmpty: [ 
		:scopes | 
		scopes do: [ :scope | 
			scope attributes
				detect: [ :implicitVariable | 
				implicitVariable name = aVariableName ]
				ifFound: [ :found | ^ found ] ] ]."
	(self
		 determineAttributeWithName: aVariableName
		 fromFamixEntity: aFamixMethod) ifNotNil: [ :found | ^ found ].
	^ nil
]

{ #category : #private }
CRFBinderVisitor >> distanceOf: element1 with: baseElement [
	| fromSourceAnchor |
	fromSourceAnchor := self sourceFamixEntity sourceAnchor.
	^ (baseElement startPos + fromSourceAnchor startPos - element1 startPos) abs + (baseElement endPos + fromSourceAnchor startPos - element1 endPos) abs
]

{ #category : #private }
CRFBinderVisitor >> sortCollection: methodsWithCorrectName byDistanceWith: aFASTJavaMethodEntity [
	^ methodsWithCorrectName sorted: [ :element1 :element2 | (self distanceOf: element1 sourceAnchor with: aFASTJavaMethodEntity) < (self distanceOf: element2 sourceAnchor with: aFASTJavaMethodEntity) ]
]

{ #category : #accessing }
CRFBinderVisitor >> sourceFamixEntity [
	^ sourceFamixEntity
]

{ #category : #accessing }
CRFBinderVisitor >> sourceFamixEntity: anObject [
	sourceFamixEntity := anObject
]

{ #category : #visitor }
CRFBinderVisitor >> sourceFamixEntityNameWithoutAnonymousPrefix [ 

	| nameString |
	nameString := self sourceFamixEntity name.
	
	"string format is '_Anonymous(ClassName)', so we remove the 11 first characters, and the final one"
	^ nameString copyFrom: 12 to: nameString size - 1
]

{ #category : #accessing }
CRFBinderVisitor >> sourceFamixEntityStartPo [
	^ self sourceFamixEntity sourceAnchor startPos
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTEntity: aFASTEntity [
	^ aFASTEntity children do: [ :child | self accept: child ]
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaAssignmentExpression: aFASTJavaAssignmentExpression [
	(self determineAttributeWithName: aFASTJavaAssignmentExpression variable name from: aFASTJavaAssignmentExpression)
		ifNotNil:
			[ :structuralEntity | structuralEntity fastAssignment add: aFASTJavaAssignmentExpression ].
	
	super visitFASTJavaAssignmentExpression: aFASTJavaAssignmentExpression.
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaClassDeclaration: aFASTJavaClassDeclaration [

	(self sourceFamixEntity allToScope: FamixTClass)
		detect: [ :class | 
			class isAnonymousClass not and: [ 
				class name = aFASTJavaClassDeclaration name ] ]
		ifFound: [ :aJavaClassDeclaration | 
			aFASTJavaClassDeclaration famixTypeDefinition: aJavaClassDeclaration ].
	
	super visitFASTJavaClassDeclaration: aFASTJavaClassDeclaration
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaClassProperty: aFASTJavaVariableDeclarator [

	| classes |
	classes := aFASTJavaVariableDeclarator type name = 'this'
		           ifFalse: [ 
			           self sourceFamixEntity mooseModel allClasses
				           detect: [ :class | 
				           class name = aFASTJavaVariableDeclarator type name ]
				           ifFound: [ :class | { class } ]
				           ifNone: [ {  } ] ]
		           ifTrue: [ self sourceFamixEntity atScope: FamixTClass ].
	classes ifNotEmpty: [ :class | 
		class anyOne fastAccesses add: aFASTJavaVariableDeclarator type.
		class anyOne attributes
			select: [ :attribute | 
			attribute name = aFASTJavaVariableDeclarator fieldName ]
			thenDo: [ :attribute | 
				attribute fastAccesses add: aFASTJavaVariableDeclarator ] ].

	super visitFASTJavaVariableDeclarator: aFASTJavaVariableDeclarator
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaFieldAccess: aFASTJavaFieldAccess [
	(self determineAttributeWithName: aFASTJavaFieldAccess fieldName from: aFASTJavaFieldAccess)
		ifNotNil:
			[ :structuralEntity | structuralEntity fastAccesses add: aFASTJavaFieldAccess ].
		
	super visitFASTJavaAssignmentExpression: aFASTJavaFieldAccess.
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaIdentifier: aFASTJavaIdentifier [
	(self determineAttributeWithName: aFASTJavaIdentifier name from: aFASTJavaIdentifier) ifNotNil: [ :structuralEntity | 
		structuralEntity fastAccesses add: aFASTJavaIdentifier ].
	super visitFASTJavaIdentifier: aFASTJavaIdentifier
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaInitializer: aFASTJavaInitializer [
	(self sourceFamixEntity allToScope: FamixTMethod)
		detect: [ :method | 
			method name = '<Initializer>' and: [ method hasSourceAnchor
				and: [ | sourceStartPos |
					sourceStartPos := self sourceFamixEntityStartPo.
					method sourceAnchor startPos - sourceStartPos <= (aFASTJavaInitializer startPos + 1)
						and: [ method sourceAnchor endPos - sourceStartPos >= (aFASTJavaInitializer endPos - 1) ] ] ] ]
		ifFound: [ :methodWithCorrectName | methodWithCorrectName fast: aFASTJavaInitializer ].
	aFASTJavaInitializer statementBlock ifNotNil: [ :statementBlock | self accept: statementBlock ]
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaInterfaceDeclaration: aFASTJavaInterfaceDeclaration [

	(self sourceFamixEntity allToAnyScope: {FamixTClass . FamixJavaInterface})
		detect: [ :class | 
			class isAnonymousClass not and: [ 
				class name = aFASTJavaInterfaceDeclaration name ] ]
		ifFound: [ :aJavaClassDeclaration | 
			aFASTJavaInterfaceDeclaration famixTypeDefinition:
				aJavaClassDeclaration ].

	super visitFASTJavaInterfaceDeclaration:
		aFASTJavaInterfaceDeclaration
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaMethodEntity: aFASTJavaMethodEntity [

	(aFASTJavaMethodEntity parentNode isNil and: [ self compareSourceFamixEntityNameWithFastEntityName: aFASTJavaMethodEntity name ])
		ifTrue: [ "The current node is the root of the analysis" self sourceFamixEntity fast: aFASTJavaMethodEntity ]
		ifFalse: [ "The method is declared inside the root, so we need to use the sourceAnchor to be sure of the binding"
			((self sourceFamixEntity allToScope: FamixTMethod)
				select: [ :method | 
					method name = aFASTJavaMethodEntity name
						and: [ method hasSourceAnchor
								and: [ | sourceStartPos |
									sourceStartPos := self sourceFamixEntityStartPo.
									method sourceAnchor startPos - sourceStartPos <= (aFASTJavaMethodEntity startPos + 1)
										and: [ method sourceAnchor endPos - sourceStartPos >= (aFASTJavaMethodEntity endPos - 1) ] ] ] ])
				ifNotEmpty: [ :methodsWithCorrectName | (self sortCollection: methodsWithCorrectName byDistanceWith: aFASTJavaMethodEntity) first fast: aFASTJavaMethodEntity ] ].
	aFASTJavaMethodEntity statements do: [ :statement | self accept: statement ].
	aFASTJavaMethodEntity parameters do: [ :parameter | self accept: parameter ].
	aFASTJavaMethodEntity typeParameters  do: [ :typeParameter | self accept: typeParameter ].	
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaMethodInvocation: aFASTJavaMethodInvocation [
	(self sourceFamixEntity queryAllOutgoingInvocations
		select: [ :invoc | 
			(invoc hasSourceAnchor
				ifTrue: [ | sourceStartPos |
					sourceStartPos := self sourceFamixEntityStartPo.
					invoc sourceAnchor startPos - sourceStartPos >= (aFASTJavaMethodInvocation startPos - 1)
						and: [ invoc sourceAnchor endPos - sourceStartPos <= (aFASTJavaMethodInvocation endPos + 1) ] ]
				ifFalse: [ invoc to first name beginsWith: aFASTJavaMethodInvocation name ]) ])
		ifNotEmpty: [ :collectionOfPotentialInvoc | 
					(collectionOfPotentialInvoc sorted: [ :invoc1 :invoc2 | invoc1 sourceAnchor intervalAsCharPos size > invoc2 sourceAnchor intervalAsCharPos size ]) first
				fast: aFASTJavaMethodInvocation ].
	super visitFASTJavaMethodInvocation: aFASTJavaMethodInvocation
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaNewClassExpression: aFASTJavaNewClassExpression [

	"the dectected binding must be an anonymous class (because we are in a FASTJavaNewClassExpression and not in a new Expression)"

	(self sourceFamixEntity allToScope: FamixTClass)
		select: [ :class | 
			class isAnonymousClass and: [ 
				(class name includesSubstring: '(' , aFASTJavaNewClassExpression type fullName , ')') and: [ 
					class hasSourceAnchor and: [ 
						| sourceStartPos |
						sourceStartPos := self sourceFamixEntityStartPo.
						class sourceAnchor startPos - sourceStartPos >= (aFASTJavaNewClassExpression startPos - 1) and: [ 
							class sourceAnchor endPos - sourceStartPos <= (aFASTJavaNewClassExpression endPos + 1) ] ] ] ] ]
		thenDo: [ :newClassExpression | aFASTJavaNewClassExpression famixType: newClassExpression ].
	"aFASTJavaNewClassExpression are kind og FASTJavaNewExpression, so execute also its visitor"
	self visitFASTJavaNewExpression: aFASTJavaNewClassExpression
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaNewExpression: aFASTJavaNewExpression [

	"We base the selection on sourceAnchor because it is the the most precise thing we have
	However, we accept a one character error because it can happens with the source anchor of verveineJ"

	(self sourceFamixEntity queryAllOutgoingInvocations select: [ :invoc | 
		 invoc candidates anyOne isConstructor and: [ 
			 invoc hasSourceAnchor and: [ 
				 | sourceStartPos |
				 sourceStartPos := self sourceFamixEntityStartPo.
				 invoc sourceAnchor startPos - sourceStartPos
				 >= (aFASTJavaNewExpression startPos - 1) and: [ 
					 invoc sourceAnchor endPos - sourceStartPos
					 <= (aFASTJavaNewExpression endPos + 1) ] ] ] ]) ifNotEmpty: [ 
		:collectionOfPotentialInvoc | 
		| sortedPotentialInvoc |
		sortedPotentialInvoc := self
			                        sortCollection: collectionOfPotentialInvoc
			                        byDistanceWith: aFASTJavaNewExpression.
		(((aFASTJavaNewExpression isKindOf: FASTJavaNewExpression) 
			  and: [
				  aFASTJavaNewExpression receiverOwner isNotNil and: [ 
					  aFASTJavaNewExpression receiverOwner isKindOf:
						  FASTJavaNewExpression ] ])
			 ifTrue: [ sortedPotentialInvoc last.  ]
			 ifFalse: [ sortedPotentialInvoc first ]) fast:
			aFASTJavaNewExpression ].
	super visitFASTJavaNewExpression: aFASTJavaNewExpression
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaParameter: aFASTJavaParameter [
	(self determineAttributeWithName: aFASTJavaParameter variable name from: aFASTJavaParameter)
		ifNotNil: [ :structuralEntity | structuralEntity fastDeclaration add: aFASTJavaParameter ]
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaTypeParameter: aFASTJavaTypeParameter [

	(self sourceFamixEntity allToScope: FamixTType)
		detect: [ :type | type name = aFASTJavaTypeParameter name ]
		ifOne: [ :type | type fastTypeDefinition: aFASTJavaTypeParameter ]
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTJavaVariableDeclarator: aFASTJavaVariableDeclarator [
	(self determineAttributeWithName: aFASTJavaVariableDeclarator variable name from: aFASTJavaVariableDeclarator)
		ifNotNil:
			[ :structuralEntity | structuralEntity fastDeclaration add: aFASTJavaVariableDeclarator ].		
	super visitFASTJavaVariableDeclarator: aFASTJavaVariableDeclarator.
]

{ #category : #generated }
CRFBinderVisitor >> visitFASTJavaVariableExpression: aFASTJavaVariableExpression [
	^self visitFASTTVariableExpression: aFASTJavaVariableExpression
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTTReturnStatement: aFASTReturnStatement [
	aFASTReturnStatement expression
		ifNotNil: [ self accept: aFASTReturnStatement expression ]
]

{ #category : #visitor }
CRFBinderVisitor >> visitFASTTVariableExpression: aFASTVariableExpression [
	(self determineAttributeWithName: aFASTVariableExpression name from: aFASTVariableExpression)
		ifNotNil:
			[ :structuralEntity | structuralEntity fastAccesses add: aFASTVariableExpression ].
	super visitFASTTVariableExpression: aFASTVariableExpression.
]
