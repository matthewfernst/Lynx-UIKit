import convert from "convert-units";

import { Context } from "../../index";
import { MeasurementSystem } from "../../types";

interface Args {
    system: MeasurementSystem;
}

const verticalDistance = (parent: any, args: Args, context: Context, info: any) => {
    if (args.system === "IMPERIAL") {
        return convert(parent.verticalDistance).from("m").to("ft");
    }
    return parent.verticalDistance;
};

export default verticalDistance;
