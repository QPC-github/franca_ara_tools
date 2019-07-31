package org.genivi.faracon

import autosar40.adaptiveplatform.applicationdesign.portinterface.Field
import autosar40.adaptiveplatform.applicationdesign.portinterface.ServiceInterface
import autosar40.autosartoplevelstructure.AUTOSAR
import autosar40.commonstructure.implementationdatatypes.ImplementationDataType
import autosar40.genericstructure.generaltemplateclasses.arpackage.ARPackage
import autosar40.genericstructure.generaltemplateclasses.primitivetypes.ArgumentDirectionEnum
import autosar40.swcomponent.datatype.dataprototypes.VariableDataPrototype
import autosar40.swcomponent.portinterface.ArgumentDataPrototype
import autosar40.swcomponent.portinterface.ClientServerOperation
import com.google.inject.Inject
import java.util.Collection
import org.franca.core.franca.FModel
import org.genivi.faracon.ara2franca.FrancaTypeCreator

import static org.genivi.faracon.util.AutosarUtil.*

class ARA2FrancaTransformation extends ARA2FrancaBase {

	@Inject
	var extension FrancaTypeCreator araTypeCreator

	/**
	 * Transforms the relevant elements of an ArPackage to a FrancaModel.
	 * Only considers the actual elements within the package.
	 */
	def create createFModel transform(ARPackage arPackage) {
		it.name = getPackageNamespace(arPackage)

		val serviceInterfaces = arPackage.elements.filter(ServiceInterface)
		val francaInterfaces = serviceInterfaces.map[transform]
		it.interfaces.addAll(francaInterfaces)
		val implementationDataTypes = arPackage.elements.filter(ImplementationDataType)
		val types = implementationDataTypes.map[transform]

		if (!francaInterfaces.isNullOrEmpty) {
			// TODO: eliminate simplification for the prototype (just puts all type definitions into the first interface definition).
			val typeInterface = francaInterfaces.get(0)
			typeInterface.types.addAll(types)
		}
	}

	def Collection<FModel> transform(AUTOSAR src) {
		val Collection<ARPackage> relevantPackages = newArrayList
		collectPackagesWithElementsOrLeafPackages(src.arPackages, relevantPackages,
			newArrayList(ServiceInterface, ImplementationDataType))
		val fModels = relevantPackages.map[it.transform()].toList
		return fModels
	}

	def create fac.createFInterface transform(ServiceInterface src) {
		if (!src.namespaces.isNullOrEmpty && !namespaceMathchesHierarchy(src)) {
			logger.logError('''Namespaces are not supported by Franca. Franca only uses the package hierarchy to identify namespaces. �
			�Namespaces can only be transformed from Autosar to Franca if they the namespace matches the package hierarchy namespace.�
			�The following Autosar namespaces defined for the interface "�src.shortName�" can not be transformed: "�src.namespaces.map[shortName].join(", ")�"''')
		}
		name = src.shortName
		broadcasts.addAll(src.events.map[transform])
		attributes.addAll(src.fields.map[transform])
		methods.addAll(src.methods.map[transform])
	}
	
	def create fac.createFBroadcast transform(VariableDataPrototype src) {
		name = src.shortName
		val outArg = fac.createFArgument => [
			// As there is no "real" name for the out-parameter in AUTOSAR,
			// we reuse the name of the VariableDataPrototoype
			name = src.shortName
			type = createFTypeRef(src.type as ImplementationDataType)
		]
		outArgs.add(outArg)
	}

	def create fac.createFAttribute transform(Field src) {
		name = src.shortName
		type = createFTypeRef(src.type as ImplementationDataType)
		noRead = !src.hasGetter
		noSubscriptions = !src.hasNotifier
		readonly = !src.hasSetter
	}

	def create fac.createFMethod transform(ClientServerOperation src) {
		name = src.shortName
		if (src.fireAndForget !== null) {
			fireAndForget = src.fireAndForget
		}
		inArgs.addAll(src.arguments.filter[direction == ArgumentDirectionEnum.IN].map[transform])
		outArgs.addAll(src.arguments.filter[direction == ArgumentDirectionEnum.OUT].map[transform])
		val inOutArguments = src.arguments.filter[direction == ArgumentDirectionEnum.INOUT]
		if (!inOutArguments.nullOrEmpty) {
			val errorMsg = '''The following in-out arguments cannot be transformed to franca as franca does not support in-out arguments: "�inOutArguments.map[it.shortName].join(", ")�"'''
			logger.logError(errorMsg)
		}
	}

	def create fac.createFArgument transform(ArgumentDataPrototype src) {
		name = src.shortName
		if (src.type !== null) {
			type = createFTypeRef(src.type as ImplementationDataType)
		} else {
			logger.
				logError('''Cannot create type for franca argument "�name�" because the Autosar argument has no type''')
			logger.logInfo("Using UINT32 as the default type in order to be able to continue")
			type = createDefaultTypeRef
		}

	}

}
