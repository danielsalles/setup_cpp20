// templates/shared/modules/utils.cppm
export module utils;

// It's good practice to put exported entities in a namespace,
// even if the module system itself provides some level of namespacing.
// This helps avoid polluting the global namespace when the module is imported.
export namespace MyProjectModules {
    export int multiply_by_two(int x) {
        return x * 2;
    }
} 