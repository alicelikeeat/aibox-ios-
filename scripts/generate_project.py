#!/usr/bin/env python3
"""Generate the checked-in Xcode project using Python's standard library only."""
from pathlib import Path
import hashlib
import json
root = Path(__file__).resolve().parent.parent
objects = {}
def ident(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, text):
    objects[ident(name)] = text
    return ident(name)
def quote(s):
    return json.dumps(s)
def refs(items):
    return '(' + ', '.join(items) + ',)'
products = []
groups = []
for name, directory, product_type in [('AiBox', 'App', 'application'), ('AiBoxUITests', 'UITests', 'bundle.ui-testing')]:
    files = []
    builds = []
    source_files = sorted((root / directory).glob('*.swift'))
    if name == 'AiBoxUITests': source_files.append(root / 'App/LocalMediaImport.swift')
    for file in source_files:
        ref = add(str(file.relative_to(root)), 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = '+quote(str(file.relative_to(root)))+'; sourceTree = "<group>";')
        files.append(ref)
        builds.append(add('build:'+name+':'+str(file.relative_to(root)), f'isa = PBXBuildFile; fileRef = {ref};'))
    groups.extend(ref for ref in files if ref not in groups)
    product = add(name+':product', f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if name == "AiBox" else "wrapper.cfbundle"}; path = {name}{".app" if name == "AiBox" else ".xctest"}; sourceTree = BUILT_PRODUCTS_DIR;')
    products.append(product)
    sources = add(name+':sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(builds)}; runOnlyForDeploymentPostprocessing = 0;')
    frameworks_files = []
    if name == 'AiBox':
        package = add('package', 'isa = XCLocalSwiftPackageReference; relativePath = ".";')
        dependency = add('core', f'isa = XCSwiftPackageProductDependency; package = {package}; productName = AiBoxCore;')
        frameworks_files.append(add('core:build', f'isa = PBXBuildFile; productRef = {dependency};'))
    frameworks = add(name+':frameworks', f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {refs(frameworks_files) if frameworks_files else "()"}; runOnlyForDeploymentPostprocessing = 0;')
    configs = []
    for config in ['Debug', 'Release']:
        settings = {'PRODUCT_NAME': '$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.alicelikeeat.aibox' + ('.uitests' if name != 'AiBox' else ''), 'GENERATE_INFOPLIST_FILE':'YES', 'CODE_SIGN_STYLE':'Automatic', 'TARGETED_DEVICE_FAMILY':'1,2', 'SWIFT_VERSION':'5.0', 'IPHONEOS_DEPLOYMENT_TARGET':'16.0', 'CURRENT_PROJECT_VERSION':'1', 'MARKETING_VERSION':'0.1.1'}
        if name == 'AiBox':
            settings.update({'INFOPLIST_KEY_CFBundleDisplayName':'AiBox', 'INFOPLIST_KEY_UILaunchScreen_Generation':'YES', 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES', 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight', 'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight UIInterfaceOrientationPortraitUpsideDown'})
        else:
            settings['TEST_TARGET_NAME'] = 'AiBox'
        configs.append(add(name+':'+config, 'isa = XCBuildConfiguration; name = '+config+'; buildSettings = {'+' '.join(f'{k} = {quote(v)};' for k,v in settings.items())+'};'))
    configlist = add(name+':configs', f'isa = XCConfigurationList; buildConfigurations = {refs(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    dependencies = []
    if name != 'AiBox':
        proxy = add('app:proxy', f'isa = PBXContainerItemProxy; containerPortal = {ident("project")}; proxyType = 1; remoteGlobalIDString = {ident("AiBox:target")}; remoteInfo = AiBox;')
        dependencies.append(add('app:dependency', f'isa = PBXTargetDependency; target = {ident("AiBox:target")}; targetProxy = {proxy};'))
    add(name+':target', f'isa = PBXNativeTarget; name = {name}; productName = {name}; productReference = {product}; productType = "com.apple.product-type.{product_type}"; buildConfigurationList = {configlist}; buildPhases = {refs([sources, frameworks])}; buildRules = (); dependencies = {refs(dependencies) if dependencies else "()"}; packageProductDependencies = {refs([ident("core")]) if name == "AiBox" else "()"};')
productgroup = add('products', f'isa = PBXGroup; name = Products; children = {refs(products)}; sourceTree = "<group>";')
main = add('main', f'isa = PBXGroup; children = {refs(groups+[productgroup])}; sourceTree = "<group>";')
configs = []
for config in ['Debug', 'Release']:
    configs.append(add('project:'+config, f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{SDKROOT = iphoneos; CLANG_ENABLE_MODULES = YES; SWIFT_OPTIMIZATION_LEVEL = "{"-Onone" if config == "Debug" else "-O"}"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; '+('ENABLE_TESTABILITY = YES; ONLY_ACTIVE_ARCH = YES; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if config == 'Debug' else '')+'};'))
configlist = add('project:configs', f'isa = XCConfigurationList; buildConfigurations = {refs(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
add('project', f'isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600;}}; buildConfigurationList = {configlist}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {productgroup}; projectDirPath = ""; projectRoot = ""; targets = {refs([ident("AiBox:target"), ident("AiBoxUITests:target")])}; packageReferences = {refs([ident("package")])};')
project = '// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
project += '\n'.join(f'{key} = {{{value}}};' for key,value in objects.items())
project += f'\n}}; rootObject = {ident("project")}; }}\n'
(root/'AiBox.xcodeproj/project.pbxproj').write_text(project)
app = ident('AiBox:target')
test = ident('AiBoxUITests:target')
def buildable(id, name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{id}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:AiBox.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable(app,'AiBox','AiBox.app')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{buildable(test,'AiBoxUITests','AiBoxUITests.xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(app,'AiBox','AiBox.app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(app,'AiBox','AiBox.app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(root/'AiBox.xcodeproj/xcshareddata/xcschemes/AiBox.xcscheme').write_text(scheme)
