import convert from "convert-units";

import { Context } from "../../index";
import { MeasurementSystem } from "../../types";

interface Args {
    system: MeasurementSystem;
}

const distance = (parent: any, args: Args, context: Context, info: any) => {
    if (args.system === "IMPERIAL") {
        return convert(parent.distance).from("m").to("ft");
    }
    return parent.distance;
};

export default distance;
